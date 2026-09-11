import {
  deleteNotification,
  deleteNotifications,
  getNotifications,
  getNotificationStatistics,
  updateNotification,
  updateNotifications,
  type NotificationDto,
} from '@immich/sdk';
import { t } from 'svelte-i18n';
import { get } from 'svelte/store';
import { eventManager } from '$lib/managers/event-manager.svelte';
import { handleError } from '$lib/utils/handle-error';

class NotificationStore {
  notifications = $state<NotificationDto[]>([]);
  unreadCount = $state(0);
  totalCount = $state(0);
  showRead = $state(false);
  searchTerm = $state('');

  readonly readCount = $derived(Math.max(this.totalCount - this.unreadCount, 0));

  constructor() {
    eventManager.on({
      AuthLogin: () => this.refresh(),
      AuthLogout: () => this.clear(),
    });
  }

  async refresh() {
    try {
      const search = this.searchTerm.trim();
      const [notifications, statistics] = await Promise.all([
        getNotifications({ unread: this.showRead ? undefined : true, search: search || undefined }),
        getNotificationStatistics(),
      ]);
      this.notifications = notifications;
      this.unreadCount = statistics.unread;
      this.totalCount = statistics.total;
    } catch (error) {
      const translate = get(t);
      handleError(error, translate('errors.failed_to_load_notifications'));
    }
  }

  setSearchTerm = async (value: string) => {
    this.searchTerm = value;
    await this.refresh();
  };

  setShowRead = async (value: boolean) => {
    this.showRead = value;
    await this.refresh();
  };

  markAsRead = async (id: string) => {
    this.notifications = this.notifications.filter((notification) => notification.id !== id);
    await updateNotification({ id, notificationUpdateDto: { readAt: new Date().toISOString() } });
    await this.refresh();
  };

  markAllAsRead = async () => {
    const ids = this.notifications.filter(({ readAt }) => !readAt).map(({ id }) => id);
    this.notifications = [];
    if (ids.length > 0) {
      await updateNotifications({ notificationUpdateAllDto: { ids, readAt: new Date().toISOString() } });
    }
    await this.refresh();
  };

  remove = async (id: string) => {
    this.notifications = this.notifications.filter((notification) => notification.id !== id);
    await deleteNotification({ id });
    await this.refresh();
  };

  clearRead = async () => {
    await deleteNotifications({ notificationDeleteAllDto: { read: true } });
    await this.refresh();
  };

  clear = () => {
    this.notifications = [];
    this.unreadCount = 0;
    this.totalCount = 0;
    this.searchTerm = '';
    this.showRead = false;
  };
}

export const notificationManager = new NotificationStore();
