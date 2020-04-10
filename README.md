# Mic-Manager
I was tired of dealing with different VOIP software and how they all handle your microphone differently, I wanted a consistent experience regardless of which software I was using. I wrote this script to manage the user selected microphone at the system level and implement various talking modes.

**This script uses the Vista Audio controls library, details of that library can be found here https://autohotkey.com/board/topic/21984-/**

**Overview:**
When the script is first launched it will default to managing the default system recording device. The options menu will display all the available capture devices on the system and allow you to choose a different device to manage if you'd like. Your selection will be saved to a .ini file and loaded at startup from that point on. If your system devices have changed and the device you had selected is no longer available, the script will default back to the default system recording device. The script will also remember it's last position on your screen between sessions. If your monitor configuration has changed and the last known position is outside of your current display resolution, the window will be shown at the default location. Your tap to talk timeout threshold and time settings will also be remebered between sessions. Closing the window will exit the script, minimizing the window will hide the gui but the script will continue to run. To reopen the window simply double click on the icon in the system tray.

**Usage:**
Capslock is the key used to toggle the mute status in the various modes. I tried a few different keys and that's what worked best for me. To send the native capslock function, just hold any other modifying key like control, shift, alt, or the windows key and press capslock. Future state, I hope to add support to allow the user to easily change the key used to toggle from the options menu. **Quickly double tap capslock to cycle between the modes.** There are currently 3 modes available.
 - **Toggle Mode:** Every single press of capslock will toggle the mute status of the selected device.
 - **Hold to talk mode:** Press and hold capslock to unmute the selected device, the device will stay unmuted until you release capslock.
 - **Tap to talk mode:** Press the capslock key to unmute your selected device. Your device will stay unmuted as long as the line in volume stays above the threshold defined in the options menu. Once your line in volume falls below the threshold, the tap to talk timeout timer will begin. A blue progress bar on the main window will show the status of this timer. The length of this timeout time is configurable in the options menu. If at any point your device's line in volume exceeds the threshold while the timeout timer is running, the timer will reset. Once the timeout timer has expired, your device will be muted. Press the capslock key again at anytime to stop the timer and manually mute your device.
 

 
 
  

