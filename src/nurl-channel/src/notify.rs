//! Manage DBUS notifications

use notify_rust::Notification;

/// Notification entrypoint
pub fn notify(name: &str, latest: &str) {
    let sent = Notification::new()
        .summary("Source updated")
        .body(&format!("{name}: {latest}"))
        .show();
    if let Err(error) = sent {
        eprintln!("warning: notification failed: {error}");
    }
}

// TODO :
//  - custom formatting
//  - make it possible to run from systemd-service (if dbus is available)
//  - post-pone notification for when the update has been done
// MAYBE : custom icon ?
