<script lang="ts">
  import { goto } from '$app/navigation';
  import { focusTrap } from '$lib/actions/focus-trap';
  import NotificationItem from '$lib/components/shared-components/navigation-bar/NotificationItem.svelte';
  import { notificationManager } from '$lib/stores/notification-manager.svelte';
  import { handleError } from '$lib/utils/handle-error';
  import { NotificationType, type NotificationDto } from '@immich/sdk';
  import { Button, Icon, Scrollable, Stack, Text, toastManager } from '@immich/ui';
  import { mdiBellOutline, mdiCheckAll, mdiTrashCanOutline } from '@mdi/js';
  import { t } from 'svelte-i18n';
  import { flip } from 'svelte/animate';
  import { fade } from 'svelte/transition';

  const noListedNotifications = $derived(notificationManager.notifications.length === 0);
  const noUnreadNotifications = $derived(notificationManager.unreadCount === 0);
  const noReadNotifications = $derived(notificationManager.readCount === 0);

  const onSearchInput = async (event: Event) => {
    await notificationManager.setSearchTerm((event.currentTarget as HTMLInputElement).value);
  };

  const onShowReadChange = async (event: Event) => {
    await notificationManager.setShowRead((event.currentTarget as HTMLInputElement).checked);
  };

  const removeNotification = async (id: string) => {
    try {
      await notificationManager.remove(id);
    } catch (error) {
      handleError(error, $t('errors.failed_to_remove_notification'));
    }
  };

  const clearRead = async () => {
    try {
      await notificationManager.clearRead();
      toastManager.info($t('cleared_read_notifications'));
    } catch (error) {
      handleError(error, $t('errors.failed_to_remove_notification'));
    }
  };

  const markAsRead = async (id: string) => {
    try {
      await notificationManager.markAsRead(id);
    } catch (error) {
      handleError(error, $t('errors.failed_to_update_notification_status'));
    }
  };

  const markAllAsRead = async () => {
    try {
      await notificationManager.markAllAsRead();
      toastManager.info($t('marked_all_as_read'));
    } catch (error) {
      handleError(error, $t('errors.failed_to_update_notification_status'));
    }
  };

  const handleNotificationAction = async (notification: NotificationDto) => {
    switch (notification.type) {
      case NotificationType.AlbumInvite:
      case NotificationType.AlbumUpdate: {
        if (!notification.data) {
          return;
        }

        if (typeof notification.data !== 'string') {
          return;
        }

        const data = JSON.parse(notification.data);
        if (data?.albumId) {
          await goto(`/albums/${data.albumId}`);
        }

        break;
      }

      default: {
        break;
      }
    }
  };

  const onclick = async (notification: NotificationDto) => {
    await markAsRead(notification.id);
    await handleNotificationAction(notification);
  };
</script>

<div
  in:fade={{ duration: 100 }}
  out:fade={{ duration: 100 }}
  id="notification-panel"
  class="absolute top-17.5 right-6 z-1 w-[min(360px,100vw-50px)] rounded-3xl border border-gray-200 bg-gray-100 text-light shadow-lg dark:border dark:border-light dark:bg-immich-dark-gray"
  use:focusTrap
>
  <Stack class="max-h-125">
    <div class="mx-4 mt-4 flex items-center justify-between">
      <Text size="medium" color="secondary" fontWeight="semi-bold">{$t('notifications')}</Text>
      <div class="flex items-center gap-1">
        <Button
          variant="ghost"
          disabled={noUnreadNotifications}
          leadingIcon={mdiCheckAll}
          size="small"
          color="primary"
          onclick={() => markAllAsRead()}>{$t('mark_all_as_read')}</Button
        >
        <Button
          variant="ghost"
          disabled={noReadNotifications}
          leadingIcon={mdiTrashCanOutline}
          size="small"
          color="primary"
          data-testid="notification-clear-read"
          onclick={() => clearRead()}>{$t('clear_read')}</Button
        >
      </div>
    </div>

    <div class="mx-4 mt-2 flex flex-col gap-2">
      <input
        type="search"
        data-testid="notification-search"
        aria-label={$t('search_notifications')}
        placeholder={$t('search_notifications')}
        value={notificationManager.searchTerm}
        oninput={onSearchInput}
        class="w-full rounded-2xl border border-gray-300 bg-white px-3 py-1.5 text-sm dark:border-gray-600 dark:bg-immich-dark-gray"
      />
      <label class="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-300">
        <input
          type="checkbox"
          data-testid="notification-show-read"
          checked={notificationManager.showRead}
          onchange={onShowReadChange}
        />
        {$t('show_read_notifications')}
      </label>
    </div>

    <hr class="mt-2 dark:border-black" />

    {#if noListedNotifications}
      <Stack
        class="flex flex-col place-content-center place-items-center py-12 text-gray-700 dark:text-gray-300"
        gap={1}
      >
        <Icon icon={mdiBellOutline} size="20"></Icon>
        <Text>{$t('no_notifications')}</Text>
      </Stack>
    {:else}
      <Scrollable class="pb-6">
        <Stack gap={0}>
          {#each notificationManager.notifications as notification (notification.id)}
            <div animate:flip={{ duration: 400 }}>
              <NotificationItem {notification} {onclick} onremove={removeNotification} />
            </div>
          {/each}
        </Stack>
      </Scrollable>
    {/if}
  </Stack>
</div>
