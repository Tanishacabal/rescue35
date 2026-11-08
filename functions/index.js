const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

initializeApp();

const db = getFirestore();

async function notifyUser(userId, eventId, notification, data) {
  const userRef = db.collection('users').doc(userId);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    console.warn(`Cannot notify missing user ${userId}.`);
    return;
  }

  await userRef.collection('notifications').doc(eventId).set({
    ...notification,
    ...data,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const user = userSnapshot.data();
  const tokens = [
    ...(Array.isArray(user.fcmTokens) ? user.fcmTokens : []),
    user.fcmToken,
  ].filter((token, index, all) => (
    typeof token === 'string' && token.length > 0 && all.indexOf(token) === index
  )).slice(0, 500);

  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    ),
    android: {
      priority: 'high',
      notification: {
        channelId: 'high_importance_channel',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (
      !result.success &&
      [
        'messaging/invalid-registration-token',
        'messaging/registration-token-not-registered',
      ].includes(result.error?.code)
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    const updates = {
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
    };
    if (invalidTokens.includes(user.fcmToken)) updates.fcmToken = '';
    await userRef.update(updates);
  }
}

exports.notifyRespondersOfNewRequest = onDocumentCreated(
  'transport_requests/{requestId}',
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const responders = await db.collection('users')
      .where('role', '==', 'responder')
      .where('accountStatus', '==', 'verified')
      .get();

    const trackingNumber = request.trackingNumber
      ? ` (${request.trackingNumber})`
      : '';
    const notification = {
      title: 'New transport request',
      body: `A new transport request${trackingNumber} needs attention.`,
    };
    const data = {
      type: 'new_request',
      requestId: event.params.requestId,
    };

    await Promise.all(responders.docs.map((responder) => (
      notifyUser(responder.id, event.id, notification, data)
    )));
  },
);

exports.notifyCitizenOfRequestStatus = onDocumentUpdated(
  'transport_requests/{requestId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const userId = after.userID;
    if (typeof userId !== 'string' || userId.length === 0) {
      console.warn(`Request ${event.params.requestId} has no userID.`);
      return;
    }

    const trackingNumber = after.trackingNumber
      ? ` ${after.trackingNumber}`
      : '';
    const status = String(after.status ?? 'updated')
      .replaceAll('-', ' ')
      .replace(/\b\w/g, (letter) => letter.toUpperCase());

    await notifyUser(
      userId,
      event.id,
      {
        title: 'Transport request update',
        body: `Your request${trackingNumber} is now ${status}.`,
      },
      {
        type: 'request_status',
        requestId: event.params.requestId,
      },
    );
  },
);

function getResponderIds(schedule) {
  return Array.isArray(schedule.responderIDs)
    ? [...new Set(schedule.responderIDs.filter(
      (id) => typeof id === 'string' && id.length > 0,
    ))]
    : [];
}

function getManilaDateParts(date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).formatToParts(date);
  return Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, Number(part.value)]),
  );
}

function formatScheduleTime(schedule) {
  const date = schedule.scheduleDate?.toDate?.();
  const time = typeof schedule.scheduleTime === 'string'
    ? schedule.scheduleTime.trim()
    : '';
  if (!date || !time) return '';
  return ` for ${date.toLocaleDateString('en-US', {
    timeZone: 'Asia/Manila',
    month: 'short',
    day: 'numeric',
  })} at ${time}`;
}

function getScheduledAt(schedule) {
  const scheduleDate = schedule.scheduleDate?.toDate?.();
  const time = typeof schedule.scheduleTime === 'string'
    ? schedule.scheduleTime.trim()
    : '';
  if (!scheduleDate || !time) return null;

  const dateParts = getManilaDateParts(scheduleDate);
  const match = time.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
  if (!match) return null;

  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const period = match[3]?.toUpperCase();
  if (
    minute > 59 ||
    (period && (hour < 1 || hour > 12)) ||
    (!period && hour > 23)
  ) {
    return null;
  }
  if (period === 'AM' && hour === 12) hour = 0;
  if (period === 'PM' && hour !== 12) hour += 12;

  return Date.UTC(
    dateParts.year,
    dateParts.month - 1,
    dateParts.day,
    hour,
    minute,
  ) - 8 * 60 * 60 * 1000;
}

exports.notifyRespondersOfAssignment = onDocumentWritten(
  'transport_schedules/{scheduleId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const previousResponderIds = new Set(getResponderIds(before ?? {}));
    const newlyAssigned = getResponderIds(after)
      .filter((responderId) => !previousResponderIds.has(responderId));
    if (newlyAssigned.length === 0) return;

    const scheduleLabel = formatScheduleTime(after);
    await Promise.all(newlyAssigned.map((responderId) => (
      notifyUser(
        responderId,
        `${event.id}-${responderId}`,
        {
          title: 'New schedule assigned',
          body: `You have been assigned a new transport schedule${scheduleLabel}.`,
        },
        {
          type: 'schedule_assignment',
          scheduleId: event.params.scheduleId,
        },
      )
    )));
  },
);

exports.notifyRespondersFiveMinutesBeforeSchedule = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'Asia/Manila',
    maxInstances: 1,
  },
  async () => {
    const now = new Date();
    const dateParts = getManilaDateParts(now);
    const dayStart = Date.UTC(
      dateParts.year,
      dateParts.month - 1,
      dateParts.day,
    ) - 8 * 60 * 60 * 1000;
    const dayAfterTomorrowStart = dayStart + 2 * 24 * 60 * 60 * 1000;
    const schedules = await db.collection('transport_schedules')
      .where('scheduleDate', '>=', new Date(dayStart))
      .where('scheduleDate', '<', new Date(dayAfterTomorrowStart))
      .get();

    const reminderWindowStart = now.getTime() - 60 * 1000;
    const reminderWindowEnd = now.getTime() + 60 * 1000;
    for (const scheduleDoc of schedules.docs) {
      const schedule = scheduleDoc.data();
      if (schedule.status === 'completed') continue;

      const scheduledAt = getScheduledAt(schedule);
      if (
        scheduledAt === null ||
        scheduledAt - 5 * 60 * 1000 < reminderWindowStart ||
        scheduledAt - 5 * 60 * 1000 >= reminderWindowEnd
      ) {
        continue;
      }

      const reminderId = `schedule-reminder-${scheduledAt}`;
      const markerRef = scheduleDoc.ref
        .collection('notification_events')
        .doc(reminderId);
      if ((await markerRef.get()).exists) continue;

      await Promise.all(getResponderIds(schedule).map((responderId) => (
        notifyUser(
          responderId,
          `${reminderId}-${responderId}`,
          {
            title: 'Upcoming transport schedule',
            body: `Your transport schedule starts in 5 minutes${formatScheduleTime(schedule)}.`,
          },
          {
            type: 'schedule_reminder',
            scheduleId: scheduleDoc.id,
          },
        )
      )));
      await markerRef.set({ sentAt: FieldValue.serverTimestamp() });
    }
  },
);
