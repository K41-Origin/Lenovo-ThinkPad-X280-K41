import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// K41 owns org.freedesktop.Notifications after the deployer disables the
// host notification server. Keep exactly one instance in Topbar.qml.
QtObject {
    id: root

    readonly property bool backendAvailable: true
    readonly property string status: "K41 notification service active"
    property var list: []
    readonly property int count: list.length
    property bool loaded: false

    function remove(entry): void {
        if (!list.includes(entry))
            return;
        list = list.filter(item => item !== entry);
    }

    function clear(): void {
        for (const entry of list.slice())
            entry.close();
    }

    function save(): void {
        if (!loaded)
            return;
        const data = list.filter(entry => !entry.transient).map(entry => ({
            notificationId: entry.notificationId,
            appName: entry.appName,
            appIcon: entry.appIcon,
            summary: entry.summary,
            body: entry.body,
            image: entry.image,
            urgency: entry.urgency,
            resident: entry.resident,
            expireTimeout: entry.expireTimeout,
            time: entry.time.toISOString()
        }));
        storage.setText(JSON.stringify(data));
    }

    onListChanged: saveTimer.restart()

    Timer {
        id: saveTimer
        interval: 750
        onTriggered: root.save()
    }

    FileView {
        id: storage
        path: Quickshell.statePath("k41-notifications.json")
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (!Array.isArray(data))
                    throw new Error("notification state is not an array");
                for (const saved of data.slice(0, 100)) {
                    if (!saved || typeof saved.summary !== "string")
                        continue;
                    const entry = entryFactory.createObject(root, {
                        notificationId: Number(saved.notificationId) || 0,
                        appName: String(saved.appName || "Unknown"),
                        appIcon: String(saved.appIcon || ""),
                        summary: saved.summary,
                        body: String(saved.body || ""),
                        image: String(saved.image || ""),
                        urgency: Number(saved.urgency) || 1,
                        resident: Boolean(saved.resident),
                        expireTimeout: -1,
                        time: saved.time ? new Date(saved.time) : new Date(),
                        transient: false
                    });
                    if (entry)
                        root.list = [...root.list, entry];
                }
            } catch (error) {
                console.warn("K41: ignoring invalid notification state:", error);
            }
            root.loaded = true;
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => storage.setText("[]"));
            } else {
                console.warn("K41: could not load notification state:", error);
                root.loaded = true;
            }
        }
    }

    Component {
        id: entryFactory

        QtObject {
            id: entry

            property var notification: null
            property int notificationId: notification ? notification.id : 0
            property string appName: notification ? notification.appName : "Unknown"
            property string appIcon: notification ? notification.appIcon : ""
            property string summary: notification ? notification.summary : ""
            property string body: notification ? notification.body : ""
            property string image: notification ? notification.image : ""
            property int urgency: notification ? notification.urgency : 1
            property bool resident: notification ? notification.resident : false
            property bool transient: notification ? notification.transient : false
            property real expireTimeout: notification ? notification.expireTimeout : -1
            property date time: new Date()

            function close(): void {
                const current = notification;
                notification = null;
                if (current)
                    current.dismiss();
                root.remove(entry);
            }

            function expire(): void {
                const current = notification;
                notification = null;
                if (current)
                    current.expire();
                root.remove(entry);
            }

            function invokeAction(identifier: string): void {
                if (!notification)
                    return;
                for (const action of notification.actions) {
                    if (action.identifier === identifier) {
                        action.invoke();
                        break;
                    }
                }
            }

            readonly property var actions: notification ? notification.actions : []

            Timer {
                running: entry.notification !== null && entry.expireTimeout >= 0
                interval: entry.expireTimeout > 0 ? entry.expireTimeout * 1000 : 5000
                onTriggered: entry.expire()
            }

            Connections {
                target: entry.notification
                function onClosed(): void {
                    entry.notification = null;
                    root.remove(entry);
                }
            }
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: false
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            const entry = entryFactory.createObject(root, {
                notification: notification,
                time: new Date()
            });
            if (entry)
                root.list = [entry, ...root.list];
        }
    }

}

// K41_NOTIFICATION_BACKEND_READY
