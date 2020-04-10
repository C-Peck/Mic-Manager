;=======================================================
;Auto Execution Section
;{======================================================
    #NoEnv
    #SingleInstance force
    ;~ SetBatchLines, -1
    SetWorkingDir, %A_ScriptDir%
    Menu, Tray, Icon,%A_WinDir%\System32\DDORES.DLL, -2014
    Menu, Tray, Tip, Mic Manager 
    ;~Menu,Tray,NoStandard ;removes all standard options from the tray menu
    Menu, Tray, Add, Show Gui,ShowGui
    Menu,Tray,Default,Show Gui
    ;=======================================================
    ;Declare global variables and set intial values of others
    ;{======================================================
    global IniFile := "MicManagerSettings.ini" ;the name of the file the user settings will be saved in, will default to the scritp's directory if an absolute file path isn't specified
        , BtnHoverColor := "505050"
        , GuiBkgdColor := "5F646C" 
        , BtnSymbolColor := "White"
        , BtnBorderColor := "dbd7d3" ;off white, this never changes
        , Mode := 1
        , ModeDesc := {1:"Tap to toggle mute`nTap CapsLock to toggle the mute status of your mic"
                      ,2:"Hold to talk`nHold CapsLock to unmute your mic, your mic`nwill stay unmuted as long as you hold CapsLock"
                      ,3:"Tap to talk`nTap CapsLock to unmute your mic, your mic will stay unmuted`nuntil it falls below the set threshold for the set amount of time"}
        , BtnList := {"MicBtn":false,"ModeBtn":false,"OptionsBtn":false,"CloseBtn":false,"MinimizeBtn":false} ;object used to reset the hover status of all the buttons, each key's value will be set to true when that button is hovered over
        , CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}" ;constant used by the VA library
        , IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}" ;constant used by the VA library
        , TTTThreshold := 20 ;microphone level you must stay below for the tap to talk timer to mute your mic
        , TTTTimeout := 10 ;how long in seconds your mic must remain below the threshold before your mic is muted
        , GuiHwnd ;misc variables that need to be accessed across different functions. Declaring them here for simplicity, not the best practice for larger scripts
        , ModeBtn_Bkg_TT
        , MicBtn_Bkg_TT
        , CloseBtn_Bkg_TT
        , MinimizeBtn__Bkg_TT
        , PrevControl
        , audioMeter
        , StartMsg
        , audioClient
        , selected_id
        , selected_id_num
        , MuteStatus
        , TimerStartTime
        , TTTTimerRunning
        , PrevMuteStatus
        , SinglePress
        ;~ , selectedKey := "CapsLock" ;not used yet, future state will allow you to easily remap the key used to trigger the hotkey
        
    ;~ HotKey, % "$" . selectedKey, KeyPressDown, ; will switch to assigning the hotkey like this once the key switching feature is working
    
    ;}
    ;=======================================================
    ;Load settings from the ini file
    ;{======================================================
    SavedSettings := ["TTTThreshold","TTTTimeout","selected_id","LastPosX","LastPosY"] ;Object containing the list of variables that can be saved to the ini file
    for index,var in SavedSettings
        IniRead,%var%,%IniFile%,settings,%var%
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79
    ;if the display configuration has changed since the last instance of the script, check if the saved coordinates are 
    ;outside of the current resolution, if they are clear the LasPos variables so the Gui is shown at the default location
    (LastPosX > ScreenWidth ? LastPosX := "")
    (LastPosY > ScreenHeight ? LastPosY := "")
    ;=======================================================
    ;Build the Main Gui
    ;{======================================================
        ;=======================================================
        ;Mic Button
        ;{======================================================
        Gui, Main:New
        Gui, Add, Progress,vMicBtn_Bkg w34 h34 x15 y15 Background%BtnBorderColor%
        MicBtn_Bkg_TT := "Click or press CapsLock to toggle mute"
        Gui, Add, Progress,vMicBtn xp+2 yp+2 w30 h30 Background%GuiBkgdColor%
        Gui, Font, s28, Webdings
        Gui, Add, Text,w30 xp-4 yp-2 BackgroundTrans c%BtnSymbolColor% vMicBtn_Symbol1 ,% Chr(177) ;177 9965 9881
        Gui, Font, s26 bold, Webdings
        Gui, Add, Text,w30 xp+1 yp-2 BackgroundTrans cRed vMicBtn_Mute hidden ,% Chr(120) ;}
        ;=======================================================
        ;Mode Button
        ;{======================================================
        Gui, Add, Progress,vModeBtn_Bkg w34 h34 xp+45 yp+2 Background%BtnBorderColor%
        ModeBtn_Bkg_TT := "Click or quickly double press CapsLock to toggle modes`nCurrent Mode: " . ModeDesc[Mode]
        Gui, Add, Progress,vModeBtn xp+2 yp+2 w30 h30 Background%GuiBkgdColor%
        Gui, Font, s20 norm, WingDings
        Gui, Add, Text,w30 xp yp-1 BackgroundTrans c%BtnSymbolColor% vModeBtn_Symbol1 ,% Chr(55) ;Tap to toggle -default mode
        Gui, Font, s26 norm, WingDings
        Gui, Add, Text,w30 xp-1 yp-2 BackgroundTrans c%BtnSymbolColor% vModeBtn_Symbol2 hidden,% Chr(41) ;hold to talk
        Gui, Font, s26 norm, WingDings 2
        Gui, Add, Text,w30 xp+6 yp BackgroundTrans c%BtnSymbolColor% vModeBtn_Symbol3 hidden,% Chr(75) ;} tap to talk 
        ;=======================================================
        ;Options Button
        ;{======================================================
        Gui, Add, Progress,vOptionsBtn_Bkg w34 h34 xp+36 yp+1 Background%BtnBorderColor%
        OptionsBtn_Bkg_TT := "Click for options"
        Gui, Add, Progress,vOptionsBtn xp+2 yp+2 w30 h30 Background%GuiBkgdColor%
        Gui, Font, s25 norm, Segoe UI Symbol
        Gui, Add, Text,w30 xp+1 yp-9 BackgroundTrans c%BtnSymbolColor% vOptionsBtn_Symbol1 ,% Chr(9881) ;}177 9965 9881
        ;=======================================================
        ;Volume Meter and tap to talk timeout bar
        ;{======================================================
        Gui, Add, Progress, vVolumeLevel h5 w123 x14 y54 Background%GuiBkgdColor% c%BtnSymbolColor%,
        Gui, Add, Progress, vTimeoutProgress h5 w123 x14 yp+4 Background%GuiBkgdColor% cBlue,
        ;}
        ;=======================================================
        ;Close Button
        ;{======================================================
        Gui, Font, s15 norm, Wingdings
        Gui, Add, Progress,vCloseBtn x135 y0 w15 h14 Background%GuiBkgdColor%
        Gui, Add, Text,w30 h15 xp+1 yp-4 BackgroundTrans c%BtnSymbolColor% vCloseBtn_Symbol1,% Chr(251)
        CloseBtn_TT := "Click to close the application" ;}
        ;=======================================================
        ;Minimize Button
        ;{======================================================        
        Gui, Font, s20, Verdana
        Gui, Add, Progress,vMinimizeBtn xp-16 yp+4 w15 h14 Background%GuiBkgdColor%
        Gui, Add, Text, xp+1 yp-11 BackgroundTrans c%BtnSymbolColor% vMinimizeBtn_Symbol1,-
        MinimizeBtn_TT := "Click to minimize the window to the system tray" ;}
        ;=======================================================
        ;Apply Gui options and color
        ;{======================================================
        Gui, +hwndGUIHwnd +AlwaysOnTop +ToolWindow +LastFound -caption
        Gui, Color, %GuiBkgdColor% ;}
    ;}
    gosub OptionsGui ;build the options gui(but don't show it) to establish a list of available devices, if a selected_id is saved check if it exists on the system, if not choose the default device
    ShowOptionGui := true ;Set this to true so the next time the OptionsGui label is ran the Gui will be shown
    Start_Audio_Meter(selected_id) ;Now that the we know the selected_id (from building the OptionsGui), start the audio stream to monitor the mic input level so we can update the volume feedback progress bar
    SetTimer,UpdateMuteStatus,200 ;start the timer that looks for changes to the selected_id mute status
    Gosub, UpdateMuteStatus ;The UpdateMuteStatus timer won't run for 200 miliseconds so run the sub now so we can update the mute status button before showing the gui
    Gui, Main:Show,% "w150 h65" . (LastPosX <> "" and LastPosY <> "" ? " x" . LastPosX . " y" . LastPosY : "") ;if both x and y coordinates of the last position of the window have been loaded from the iniFile, show the window at that position, if not, the window will be shown at the default location
    WinSet, Transparent, 220, ahk_id %GUIHwnd%
    ;=======================================================
    ;Register the Gui messages we need to monitor to react to user actions
    ;{======================================================
        OnMessage(0x200, "WM_MOUSEMOVE") ;triggers everytime the mouse moves while over a Gui window
        OnMessage(0x0232, "WM_EXITSIZEMOVE") ;triggers everytime a window move of the Gui has been completed
        OnMessage(0x201, "WM_LBUTTONDOWN") ;tiggers everytime the left mouse button is pressed down while over the Gui window
        OnMessage(0x202, "WM_LBUTTONUP") ;tiggers everytime the left mouse button is released while over the Gui window
        OnMessage(0x100, "OnKeyDown") ;triggers everytime a key is pressed while the Gui window is the active window
    ;}
    return
;}
;=======================================================
;Hotkeys
;{======================================================
/*
    Will use something like this once the key switching feature is implemented
    KeyPressDown:
        if (key_presses > 0) ; SetTimer already started, so we log the keypress instead.
        {
            key_presses += 1
            return
        }
        ; Otherwise, this is the first press of a new series. Set count to 1 and start the timer:
        key_presses := 1
        SetTimer, KeyPressDownTimer, -250 ; Wait for more presses within a 250 millisecond window.
    return
    
    KeyPressDownTimer:
        if (key_presses = 1) ; The key was pressed once.
        {
            (Mode = 1 ? ToggleMute() : (Mode = 2 ? HoldToTalk(): TapToTalk()))
        }
        else if (key_presses = 2) ; The key was pressed twice.
        {
            if (selectedKey = "CapsLock")
                SetCapsLockState % !GetKeyState("CapsLock", "T") ;ToggleMode()
            else if (selectedKey = "NumLock")
                SetNumLockState % !GetKeyState("NumLock", "T")
            else
            {
                if (StrLen(selectedKey) = 1)
                    send %selectedKey%
                else
                    send {%selectedKey%}
            }
        }
        ; Regardless of which action above was triggered, reset the count to prepare for the next series of presses:
        key_presses := 0
    return
*/
    ; I think capslock is the best key to use here. Press it once to toggle mute
    ; Press it twice within 250 miliseconds to toggle the mode
    ; To send the native capslock function, just hold any other modifying key like
    ; control, shift, alt, or the windows key and press capslock.
    $CapsLock::
        if (key_presses > 0) ; SetTimer already started, so we log the keypress instead.
        {
            key_presses += 1
            return
        }
        ; Otherwise, this is the first press of a new series. Set count to 1 and start the timer:
        key_presses := 1
        SetTimer, KeyPressDownTimer, -250 ; Wait for more presses within a 250 millisecond window.
        keywait, CapsLock ;need to wait for the CapsLock key to be released before allowing another instance to fire, without this the hotkey will fire rapidly if capslock is held down
    return
    
    KeyPressDownTimer:
        if (key_presses = 1) ; The key was pressed once.
        {
            (Mode = 1 ? ToggleMute() : (Mode = 2 ? HoldToTalk(): TapToTalk()))
        }
        else if (key_presses = 2) ; The key was pressed twice so send the normal key function
        {
            ToggleMode()
        }
        ; Regardless of which action above was triggered, reset the count to prepare for the next series of presses:
        key_presses := 0
    return

    f4::reload

;}
;=======================================================
;Main Gui Control Labels 
;{======================================================
    ShowGui:
        Gui, Main:Show
    return
;}
;=======================================================
;Options Gui
;{======================================================
    ;=======================================================
    ;Build Options Gui
    ;{======================================================
        OptionsGui:
            setTimer, UpdateVolumeBar,off ;Only one audio stream is active at a time, so disable the MainGui volume bar when the OptionsGui is opened
            GuiControl,Main:,VolumeLevel,0
            Gui, Options:New, +hwndOptionsGuiHwnd ;+0x02000000
            StartMsg := 
            (LTrim
                "Select a device from the list to adjust it's properties.
                Double click a device from the list to save it as your selected device.
                The selected device is the device that will be muted with this script.
                Your Settings will be automatically saved when you close this window.
                Press F5 to refresh the list of devices."
            )
            Gui, Options:Font, s9, Consolas
            Gui, Options:Add, Edit, vCommand  r5 ReadOnly -Wrap -VScroll w515 Center disabled, % StartMsg
            Gui, Options:Font
            Gui, Options:Add, Button, gSysCtrlPnl xm+185 y+5 vSysCtrlPnlBtnText , Open sound control panel
            Gui, Options:Add, ListView, vDeviceLV gDeviceLV AltSubmit r6 w515 xm, #|System Default|Selected|Name|Adapter|ID
            ;Gui, Options:Add, ListView, vControlLV gControlLV AltSubmit r3 w500, Control|Value
            Gui, Options:Add, Text,xm+37 y+15 gVolumeText vVolumeText ,Volume:
            VolumeText_TT := "Current device input volume. Move the slider to adjust."
            Gui, Options:Add, Slider, xp+40 yp-5 vVolumeSlider gVolumeSlider Disabled w150 AltSubmit ToolTip
            Gui, Options:Add, Edit,vCurrentVolume yp x+1 r1 ReadOnly -Wrap -VScroll w40 Center disabled,100
            Gui, Options:Add, Text, x+25 yp+5 gMuteText vMuteText, Mute:
            MuteText_TT := "Current mute status of the selected device."
            Gui, Options:Add, Edit,vMuteStatus yp-5 x+5 r1 ReadOnly -Wrap -VScroll w40 Center disabled,
            Gui, Options:Font,s7
            Gui, Options:Add, Checkbox, vToggle x+5 yp-1 gToggle Disabled  w45 h23 +0x1000, Toggle
            Gui, Options:Add, Progress, vOptionsVolumeLevel cGreen BackgroundGray x101 y+10 w124 h10,0
            OptionsVolumeLevel_TT := "Current mic level of the selected device."
            Gui, Options:Add, Text, gTTTText vTTTText xm yp+22, TTT Threshold:
            TTTText_TT := 
            (LTrim
                "This is the threshold your mic volume has to remain below for
                the tap to talk timeout to mute your mic. Be sure to set this
                above your resting mic volume for tap to talk to function."
            )
            Gui, Options:Add, Slider, xp+77 yp-5 vTTTThreshold gTTTSlider w150 ToolTip, % TTTThreshold
            Gui, Options:Add, Text, gTTTTimeoutText vTTTTimeoutText x+20 yp+5, TTT Timeout:
            TTTTimeoutText_TT := 
            (LTrim
                "This is how long, in seconds, your mic level needs to
                remain below the threshold before your mic is muted."
            )
            Gui, Options:Add, Edit,vTTTTimeout yp-5 x+5 r1  -Wrap -VScroll w40 Center, % TTTTimeout
            ;~ if (AllowKeyChange) ;this feature needs more work
            ;~ {
                ;~ Gui, Options:Add, Text, vSelectedKeyText gSelectedKeyText yp+5 x+15, Toggle Key:
                ;~ SelectedKeyText_TT := 
                ;~ (LTrim
                    ;~ "This is the key pressed to toggle the mute status of the mic,
                    ;~ click inside the edit box to set a new key."
                ;~ )
                ;~ Gui, Options:Add, Edit,vSelectedKey gSelectedKey yp-5 x+5 r1 ReadOnly -Wrap -VScroll w70 Center, % SelectedKey
            ;~ }
            PopulateDeviceLV() 
            if (ShowOptionGui)
                Gui, Options:Show,, Sound Controls
        return 
    ;}
    ;=======================================================
    ;Build Key Change Gui - Not yet functional
    ;{======================================================
        ;~ KeyChangeGui:
            ;~ Gui, Options:+Disabled
            ;~ Gui, KeyChange:New, +OwnerOptions +hwndKeyChangeHwnd +ToolWindow -caption
            ;~ Gui, KeyChange:Font, s10, Consolas
            ;~ Gui, KeyChange:Add, Edit,vKeyChangeEdit r5 ReadOnly -Wrap -VScroll w260 Center disabled,`nPress the new key`nKey combinations are not supported`nPress ESC to cancel
            ;~ Gui, KeyChange:Color,CCCCCC
            ;~ WinGetPos,Ox,Oy,Ow,Oh,ahk_id %OptionsGuiHwnd%
            ;~ KCw := 285
            ;~ KCh := 100
            ;~ KCx := Round((Ow-KCw)/2)+Ox
            ;~ KCy := Round((Oh-KCh)/2)+Oy
            ;~ Gui, KeyChange:Show, x%KCx% y%KCy% w%KCw% h%KCh%,New Key Select
            ;~ keylist := "{Esc}{Tab}{LControl}{RControl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}{AppsKey}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}{Del}{Ins}{BS}{CapsLock}{NumLock}{PrintScreen}{Pause}{NumPad0}"
            ;~ Input,NewKey, L1, %keylist%
            ;~ If (Errorlevel <> "MAX")
                ;~ if (InStr(ErrorLevel,"Escape"))
                    ;~ goto, CloseKeyChangeGui
                ;~ else
                    ;~ NewKey := SubStr(ErrorLevel,8)
            ;~ if (NewKey <> SelectedKey) ;disable old hotkey before saving the new key
                ;~ SelectedKey := NewKey

            ;~ GuiControl,Options:,SelectedKey, % SelectedKey
            ;~ CloseKeyChangeGui:
            ;~ Gui, Options:-Disabled
            ;~ Gui, KeyChange:hide
        ;~ return

    ;~ SelectedKey:
    ;~ return
    ;=======================================================
    ;Options Gui Control Labels and Functions
    ;{======================================================
        DeviceLV: ;Control has the AltSubmit property so this label gets triggered more often than normal
            Gui ListView, DeviceLV
            if (A_GuiEvent = "DoubleClick")
            {
               LV_GetText(tRow,A_EventInfo,3) ;A_EventInfo contains the focused row number
               if (tRow <> ">>") ;determine if the double clicked row is already the selected device or not
                    Loop % LV_GetCount() ;loop through all the rows on the listview
                    {
                        if (A_Index = A_EventInfo) ;if this row is the focused row
                        {
                            LV_Modify(A_Index,"Col3",">>") ;set it as the selected device
                            LV_GetText(selected_id, A_EventInfo, 6) ;store the id of the selected device, used to start the audio stream to monitor the input volume
                            LV_GetText(selected_id_num, A_EventInfo, 1) ;store the number of the selected device, used for any soundset or soundget commands
                        }
                        else
                            LV_Modify(A_Index,"Col3","") ;if it's not the row that was clicked on set the cell to bank
                        
                    }
            }
            if ((A_GuiEvent = "I" && InStr(ErrorLevel, "F", true)) or (A_GuiEvent = "DoubleClick")) ;whenever a new row is selected
            {
                LV_GetText(device_num, A_EventInfo, 1) ;get the device number
                LV_GetText(id, A_EventInfo, 6) ;and id
                PopulateControl(device_num,id) ;to use to populate the controls on the OptionsGui for this device
                GuiControl, Options:Enable, Toggle
                GuiControl, Options:Enable, VolumeSlider
            }
        return

        Toggle: ;triggered everytime the toggle button is pressed or the VolumeSlider is adjusted
        VolumeSlider:
            if (A_GuiControl = "VolumeSlider") { ;if the VolumeSlider control triggered this label
                GuiControlGet, value,Options:, VolumeSlider ;the volume is being adjusted, get the current VolumeSlider position
                control_type := "Volume" ;set control_type to volume since the volume is being adjusted
            } else { ;if the toggle mute button triggered this label
                value := -1 ;a value of -1 will cause the mute status to be set to the opposite of whatever it is now
                control_type := "Mute" ;set control_type to mute for the soundset/get commands below
            }
            SoundSet % value, %component_type%, %control_type%, %device_num% ;either set the current VolumeSlider volume, or the mute status, of the current device depending on which control triggered this label
            SoundGet value, %component_type%, %control_type%, %device_num% ;get the current device value so we can update the edit boxes on the OptionsGui with the currentValue, the confirms the device was actually udpated
            if (A_GuiControl = "VolumeSlider")
                Guicontrol, Options:,CurrentVolume,% round(value)
            else
                Guicontrol, Options:,MuteStatus,% value
        return

        SysCtrlPnl: ;launches the system sound control panel
            Run rundll32.exe shell32.dll`,Control_RunDLL mmsys.cpl`,`,0
        return
        
        OptionsGuiEscape:
        OptionsGuiClose:
            Gui,Submit ;when the OptionsGui is closed, save all the values to their associated variables
            ;Save the settings to a file, instead of manually defining the variables to save can we create an object of all the loaded variables when reading from the ini file at the start of the script?
            variables := 
            (Ltrim
                "TTTThreshold = " . TTTThreshold . "
                TTTTimeout = " . TTTTimeout . "
                selected_id = """ . selected_id . """"
            )
            Iniwrite, %variables%,%IniFile%,settings
            
            setTimer, UpdateOptionsVolumeBar,off ;disable the OptionsGui volume bar if it's running
            Start_Audio_Meter(selected_id) ;restart the volume bar on the MainGui
        return
        
        ;Inorder for WM_MOUSEMOVE() to register when the mouse is over a text control there needs to be an associated label
        ;Even though these are blank, without them the tooltips wouldn't been shown when the mouse hovers over the text
        TTTSlider:
        TTTTimeoutText:
        TTTText:
        VolumeText:
        MuteText:
        selectedKeyText:
        return 
        
        PopulateControl(device_num,target_id) ;called by the DeviceLV label whenever a new row is selected in the device list view
        {
            SoundGet value, Master, Volume, %device_num% ;get the current volume of the focused device and set the volumeslider/currentvolume edit box to that value
            If (!ErrorLevel)
            {
                Guicontrol, Options:,CurrentVolume,% Round(value)
                GuiControl, Options:, VolumeSlider, % value
            }
            SoundGet value, Master, Mute, %device_num% ;get the current mute status of the focues device and update the MuteStatus edit box with that value
             If (!ErrorLevel)
            {
                Guicontrol, Options:,MuteStatus,% value
            }
            Start_Audio_Meter(target_id,"UpdateOptionsVolumeBar") ;start monitoring the audio of the focused device
        }
    ;}
;}
;=======================================================
;Global Timers and Functions
;{======================================================
    ;=======================================================
    ;Global Timers
    ;{======================================================
        ; ---------------------------------------
        ; Name: UpdateMuteStatus Timer
        ; Triggered By: Auto execution
        ; Condition: Persistent timer 
        ; Interval: 200 miliseconds
        ; Gets the current mute status of the selected device and compares it to the previous status
        ; If the status has changed, update the MainGui to show or hide the mute symbol
        ; ---------------------------------------
        UpdateMuteStatus:
            SoundGet,MuteStatus,Master,Mute,selected_id_num
            if (MuteStatus <> PrevMuteStatus) {
                Guicontrol,% "Main: Hide"(MuteStatus = "On" ? 0:1),MicBtn_Mute
                PrevMuteStatus := MuteStatus
            }
        return
        ; ---------------------------------------
        ; Name: Update[Options]VolumeBar Timer
        ; Triggered By: Start_Audio_Meter()
        ; Condition: Whenever an audio stream exists
        ; Interval: Variable devicePeriod (determined during Start_Audio_Meter())
        ; Description: Gets the current mic level (peakValue) and updates either the OptionsGui or the MainGui volume
        ;              bar depending on which label was used to start the timer
        ; ---------------------------------------
        UpdateVolumeBar:
        UpdateOptionsVolumeBar:
            VA_IAudioMeterInformation_GetPeakValue(audioMeter, peakValue)
            peakValue := peakValue*100
            if (A_ThisLabel = "UpdateVolumeBar")
            {
                tGui := "Main:"
                tControl := "VolumeLevel"
            }
            else
            {
                tGui := "Options:"
                tControl := "OptionsVolumeLevel"  
            }
            GuiControl,%tGui%,%tControl%, %peakValue%
        return
        ; ---------------------------------------
        ; Name: Tap To Talk Timeout Timer
        ; Triggered By: TapToTalk()
        ; Condition: Whenever the mode is set to 3 (tap to talk) and the toggle mute hotkey is pressed
        ; Interval: 100 miliseconds
        ; Description: Monitors the mic level when the mic is unmuted while in tap to talk mode,
        ;              determines if the mic level is above or below the timeout threshold,
        ;              checks how long the level has stayed below the threshold and mutes the mic if the
        ;              timeout time has been exceeded
        ; ---------------------------------------
        TTTTimeoutTimer:
            if (peakValue > TTTThreshold) 
            {
                GuiControl,Main:,TimeoutProgress, 0
                TimerStartTime := A_TickCount
            }
            else 
            {
                GuiControl,Main:,TimeoutProgress, % (A_TickCount - TimerStartTime)/(TTTTimeout*10)
                if (A_TickCount - TimerStartTime > TTTTimeout*1000)
                {
                    ToggleMute("On")
                    TTTTimerRunning := false
                    GuiControl,Main:,TimeoutProgress, 0
                    SetTimer, TTTTimeoutTimer,Off
                }
            }
        return
        ; ---------------------------------------
        ; Name: MouseLeaveCheck
        ; Triggered By: WM_MOUSEMOVE()
        ; Condition: Whenever a button on the MainGui has been set to the hovered state
        ; Interval: 100 miliseconds
        ; Description: If the mouse is over a button on the MainGui, the button will be set to the hovered state,
        ;              if the mouse is abruptly moved from hovering over the button to off the Gui WM_MOUSEMOVE isn't triggered so
        ;              the hover status of the button won't be reset to normal until the mouse comes back over the Gui.
        ;              This timer will check the mouse position once any button has been set to the hovered state and if
        ;              the mouse is no longer over the Gui, all the buttons will be reset to normal
        ; ---------------------------------------        
        MouseLeaveCheck:
            MouseGetPos,x,y,win
            if (win <> GUIHwnd)
            {
                ResetButtons()
                PrevControl =
                setTimer,MouseLeaveCheck,off
            }
        return
    ;}
    ;=======================================================
    ;Global Functions
    ;{======================================================
        WM_MOUSEMOVE(wParam, lParam, msg, hwnd) ;triggered everytime the mouse moves over the gui
        {
            static CurrControl, _TT, PrevX, PrevY  ; _TT is kept blank for use by the ToolTip command below.
            MouseGetPos,x,y
            if ((PrevX = x) and (PrevY = y)) ;sometimes this function will get triggered even when the mouse hasn't moved, so check if the mouse has moved since the last run and abort if it hasn't
                return
            PrevX := x , PrevY := y
            tooltip, % %A_GuiControl%_TT ;display tooltip
            ;~ tooltip % A_GuiControl A_Space A_TickCount
            ;find the position of the _ in the current control if there is one, we need to extract the text up until the _ to get the base control name ie MicBtn_Bkg > MicBtn, then we can dynamically target the other parts of the button like MicBtn_Symbol1 or MicBtn_Mute
            _pos := instr(A_GuiControl,"_"), CurrControl := _pos ? SubStr(A_GuiControl,1,_pos-1 ) : A_GuiControl ;if there's no _ just leave A_GuiControl as is
            If ((CurrControl <> PrevControl) and (A_Gui = "Main"))
            {
                ResetButtons() ;a new control is being hovered over, so reset any of the controls that are in the hovered state
                if ((CurrControl) and (CurrControl <> "VolumeLevel") and (CurrControl <> "TimeoutProgress")) ;check if the mouse is currently over a control except for the volume bars, currcontrol will be blank if the mouse is just over the gui
                {
                    BtnList[CurrControl] := true ;set the value to true for this control, this is referenced when resetting buttons to avoid unnecessarily redrawing controls
                    GuiControl,% "Main: +Background" . (CurrControl = "CloseBtn" ? "E81123" :  BtnHoverColor),%CurrControl% ;set the background color of the control being hovered over to the button hover color, unless it's the close button, then set it to red
                    loop, 3 ;the most recently drawn control will be shown above all other controls, so redraw the other controls that should be shown above the background control
                        GuiControl,Main:MoveDraw,% CurrControl . "_Symbol" . A_Index
                    GuiControl,Main:MoveDraw,%CurrControl%_Mute
                    setTimer,MouseLeaveCheck,100 ;now that a control has been set to the hover state, start this timer. See timer details for more info
                }
                PrevControl := CurrControl ;save the current control to compare to on the next run
            }
        }
        
        WM_EXITSIZEMOVE() ;Triggered everytime the MainGui has been repositioned, get the new x and y coords of the MainGui and save them to the iniFile so the script can remember it's position between sessions
        {
            WinGetPos, x, y,,,ahk_id %GuiHwnd%
            if ((x <> "") and (y <> "")) ;if the WinGetPos fails for any reason x and y will be made blank, if that happens don't write to the inifile
            {
                IniWrite,%x%,%IniFile%,settings,LastPosX
                IniWrite,%y%,%IniFile%,settings,LastPosy
            }
        }
        
        WM_LBUTTONDOWN() ;allow to click and drag if anywhere inside the gui except for on a button control is clicked
        {
            if ((A_Gui = "Main") and ((!A_GuiControl) or (A_GuiControl = "VolumeLevel") or (A_GuiControl = "TimeoutProgress")))
                PostMessage, 0xA1, 2 ;0xA1 is the message sent to a window when the title bar is clicked down on
        }

        WM_LBUTTONUP(wParam, lParam) ;detect clicks on the MainGui 
        {
            If (A_GuiControl = "MicBtn_Bkg") ;if the mic button is clicked on, toggle the mute status or trigger the tap to talk depending on what mode we're in
                if (Mode = 3)
                    TapToTalk()
                else
                    ToggleMute() 
            else If (A_GuiControl = "ModeBtn_Bkg")
                ToggleMode() ;if the mode button is clicked on, toggle the mode
            else If (A_GuiControl = "OptionsBtn_Bkg")
                Gosub, OptionsGui ;if the options button is clicked on, show the OptionsGui
            else If (A_GuiControl = "CloseBtn")
                ExitApp
            else If (A_GuiControl = "MinimizeBtn")
                Gui,Main:Hide
            ;~ else If (A_GuiControl = "SelectedKey") ;
                ;~ Gosub KeyChangeGui ;if the 
        }

        OnKeyDown(wParam) ;detects if F5 is pressed when the OptionsGui is focused
        {
            if (A_Gui = "Options")
                if (wParam = 0x74) ; VK_F5
                    PopulateDeviceLV()
        }

        ResetButtons() ;resets the hover status of any buttons that are currently set to hovered
        {
            For Btn,HoverStatus in BtnList 
            {
                if (HoverStatus){
                    GuiControl,Main: +Background%GuiBkgdColor% ,%Btn%
                    loop, 3
                        GuiControl,Main:MoveDraw,% Btn . "_Symbol" . A_Index
                    GuiControl,Main:MoveDraw,%Btn%_Mute
                    BtnList[Btn] := false
                }
            }
            tooltip	
        }
        
        PopulateDeviceLV() ;Called when the OptionsGui is being built or when F5 has been pressed. Enumerates all the audio devices on the system and adds all the capture devices to the listview
        {
            id_recheck:
            Gui ListView, DeviceLV ;Make sure the device listview is the target of the lv commands
            LV_Delete() ;remove everything currently in the listview
            enum := ComObjCreate(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator) ;Most of this is borrowed from the soundcard analysis written by Lexikos, found it archived here https://github.com/YoYo-Pete/AutoHotKeys/blob/master/Soundcard.ahk
            if VA_IMMDeviceEnumerator_EnumAudioEndpoints(enum, 2, 9, devices) >= 0  ; Uses the Vista Audio Control Library written by Lexikos https://autohotkey.com/board/topic/21984-/
            {
                VA_IMMDeviceEnumerator_GetDefaultAudioEndpoint(enum, 1, 0, device) ;1 for capture devices, 0 for playback devices
                VA_IMMDevice_GetId(device, default_id) 
                if (selected_id = "") ;if the selected_id hasn't been defined yet
                    selected_id := default_id ;set the default system communication device as the selected_id
                ObjRelease(device)
                
                VA_IMMDeviceCollection_GetCount(devices, count)
                
                Loop % count
                {
                    if VA_IMMDeviceCollection_Item(devices, A_Index-1, device) < 0
                        continue
                    VA_IMMDevice_GetId(device, id)
                    name := VA_GetDeviceName(device)
                    if !RegExMatch(name, "^(.*?) \((.*?)\)$", m)
                        m1 := name, m2 := ""
                    if (SubStr(id,6,1) = "1") ;filter to show only capture devices in the listview, we need to enumerate all the devices so the device number is correct for any soundset or soundget commands, but we only need to show the user capture devices
                        LV_Add("", id == selected_id ? selected_id_num := A_Index : A_Index, id == default_id ? ">>" : "",id == selected_id ? ">>" : "" ,m1, m2,id)
                    ObjRelease(device)
                }
                if (!selected_id_num) ;if this variable isn't defined, it means the saved selected_id wasnt found on the system, so change it to the default device and restart the function
                {
                    selected_id := default_id
                    goto, id_recheck
                }
                ObjRelease(devices)
            }
            ObjRelease(enum)
            Loop 2
                LV_ModifyCol(A_Index+3, "AutoHdr") ;autosize the Name and Adapter columns
            LV_ModifyCol(1, 0) ;hide # column
            LV_ModifyCol(6, 0) ;hide ID column
        }
        
        Start_Audio_Meter(target_id,timer_label := "UpdateVolumeBar") ;Start the audio stream to monitor the mic in level for the targeted device, defaults to the MainGui volume bar
        {
            ;Outlined by Lexikos here https://autohotkey.com/board/topic/21984-vista-audio-control-functions/page-7#entry351006
            device := VA_GetDevice(target_id)
            VA_IMMDevice_Activate(device, IID_IAudioClient:="{1CB9AD4C-DBFA-4c32-B178-C2F568A703B2}", 7, 0, audioClient) ; Get IAudioClient interface.
            VA_IAudioClient_GetMixFormat(audioClient, format) ; Get mixer format to pass to Initialize.
            VA_IAudioClient_Initialize(audioClient, 0, 0, 0, 0, format, 0) ; Initialize audio client to ensure peak meter is active.
            VA_IAudioClient_Start(audioClient) ;Start the audio stream, this was missing from Lexikos' example
            audioMeter := VA_GetAudioMeter(device) ; Get IAudioMeterInformation interface.
            ObjRelease(device) ; No longer needed, so free it
            VA_GetDevicePeriod("capture", devicePeriod) ; Get the device period
            setTimer, %timer_label%,%devicePeriod% ; start the timer to monitor the mic in level and update the appropriate volume bar
        }
        
        HoldToTalk() ;Triggered by the toggle mute hotkey when in hold to talk mode
        {
            ToggleMute("Off")
            keywait, CapsLock
            ToggleMute("On")
        }

        TapToTalk() ;Triggered by the toggle mute hotkey when in tap to talk mode
        {
            if (TTTTimerRunning) ;if TTTTimerRunning is true it means the tap to talk timer is already running so remute the mic and stop the timeout timer
            {
                TTTTimerRunning := false
                setTimer, TTTTimeoutTimer, Off
                GuiControl,Main:,TimeoutProgress, 0
                ToggleMute("On")
                return
            }
            ToggleMute("Off") ;unmute the mic
            TimerStartTime := A_TickCount ;set the intial tick count used in the TTTTimeoutTimer
            TTTTimerRunning := true ;Set TTTTimerRunning to true, this will stay true until the tap to talk timeout is reached
            setTimer, TTTTimeoutTimer, 100
        }
        
        ToggleMute(mValue := -1) ;parameter options -1 toggle mute, "On" set mute on, "Off" set mute off
        {
                SoundSet, % (mValue = -1 ? -1: (mValue = "On" ? 1 : 0)), Master, Mute, %selected_id_num%
        }

        ToggleMode()
        {
            TTTTimerRunning := false ;when the mode is changed stop the tap to talk timeout timer if it's running
            SetTimer, TTTTimeoutTimer,Off
            GuiControl,Main:,TimeoutProgress, 0
            GuiControl,Main:Hide1,ModeBtn_Symbol%Mode% ;hide the current mode before incrementing
            GuiControl,Main:Hide0,% "ModeBtn_Symbol" . (Mode > 2 ? Mode := 1:Mode := Mode+1) ;increment the mode by one, unless it's 3, in that case make it 1 then show the current mode symbol
            ModeBtn_Bkg_TT := "Click or quickly double press CapsLock to toggle modes`nCurrent Mode: " . ModeDesc[Mode] ;update the tooltip with the current mode description	
            if (Mode <> 1) ;if the mode is changed to hold to talk or tap to talk, the device should default to muted for the modes to function properly
                SoundSet, 1, Master, Mute, %selected_id_num%
            if (Mode = 2)
                 MicBtn_Bkg_TT := "Click or press and hold CapsLock to toggle mute" ;**Should we use an object that uses the mode variable to change between the different text? Similar to ModeDesc**
            else
                MicBtn_Bkg_TT := "Click or press CapsLock to toggle mute"
        }
        
    ;}
;}

;=======================================================
;VA Library Functions used by this script, Comment all these out if you'd rather include the whole VA library
;{======================================================
    VA_IAudioMeterInformation_GetPeakValue(this, ByRef Peak) {
        return DllCall(NumGet(NumGet(this+0)+3*A_PtrSize), "ptr", this, "float*", Peak)
    }

    VA_IMMDeviceEnumerator_EnumAudioEndpoints(this, DataFlow, StateMask, ByRef Devices) {
        return DllCall(NumGet(NumGet(this+0)+3*A_PtrSize), "ptr", this, "int", DataFlow, "uint", StateMask, "ptr*", Devices)
    }

    VA_IMMDeviceEnumerator_GetDefaultAudioEndpoint(this, DataFlow, Role, ByRef Endpoint) {
        return DllCall(NumGet(NumGet(this+0)+4*A_PtrSize), "ptr", this, "int", DataFlow, "int", Role, "ptr*", Endpoint)
    }

    VA_IMMDevice_GetId(this, ByRef Id) {
        hr := DllCall(NumGet(NumGet(this+0)+5*A_PtrSize), "ptr", this, "uint*", Id)
        VA_WStrOut(Id)
        return hr
    }

    VA_IMMDeviceCollection_GetCount(this, ByRef Count) {
        return DllCall(NumGet(NumGet(this+0)+3*A_PtrSize), "ptr", this, "uint*", Count)
    }

    VA_IMMDeviceCollection_Item(this, Index, ByRef Device) {
        return DllCall(NumGet(NumGet(this+0)+4*A_PtrSize), "ptr", this, "uint", Index, "ptr*", Device)
    }

    VA_GetDeviceName(device)
    {
        static PKEY_Device_FriendlyName
        if !VarSetCapacity(PKEY_Device_FriendlyName)
            VarSetCapacity(PKEY_Device_FriendlyName, 20)
            ,VA_GUID(PKEY_Device_FriendlyName :="{A45C254E-DF1C-4EFD-8020-67D146A850E0}")
            ,NumPut(14, PKEY_Device_FriendlyName, 16)
        VarSetCapacity(prop, 16)
        VA_IMMDevice_OpenPropertyStore(device, 0, store)
        ; store->GetValue(.., [out] prop)
        DllCall(NumGet(NumGet(store+0)+5*A_PtrSize), "ptr", store, "ptr", &PKEY_Device_FriendlyName, "ptr", &prop)
        ObjRelease(store)
        VA_WStrOut(deviceName := NumGet(prop,8))
        return deviceName
    }

    VA_GetDevice(device_desc="playback")
    {
        static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
            , IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
        if !(deviceEnumerator := ComObjCreate(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator))
            return 0
        
        device := 0
        
        if VA_IMMDeviceEnumerator_GetDevice(deviceEnumerator, device_desc, device) = 0
            goto VA_GetDevice_Return
        
        if device_desc is integer
        {
            m2 := device_desc
            if m2 >= 4096 ; Probably a device pointer, passed here indirectly via VA_GetAudioMeter or such.
            {
                ObjAddRef(device := m2)
                goto VA_GetDevice_Return
            }
        }
        else
            RegExMatch(device_desc, "(.*?)\s*(?::(\d+))?$", m)
        
        if m1 in playback,p
            m1 := "", flow := 0 ; eRender
        else if m1 in capture,c
            m1 := "", flow := 1 ; eCapture
        else if (m1 . m2) = ""  ; no name or number specified
            m1 := "", flow := 0 ; eRender (default)
        else
            flow := 2 ; eAll
        
        if (m1 . m2) = ""   ; no name or number (maybe "playback" or "capture")
        {
            VA_IMMDeviceEnumerator_GetDefaultAudioEndpoint(deviceEnumerator, flow, 0, device)
            goto VA_GetDevice_Return
        }

        VA_IMMDeviceEnumerator_EnumAudioEndpoints(deviceEnumerator, flow, 1, devices)
        
        if m1 =
        {
            VA_IMMDeviceCollection_Item(devices, m2-1, device)
            goto VA_GetDevice_Return
        }
        
        VA_IMMDeviceCollection_GetCount(devices, count)
        index := 0
        Loop % count
            if VA_IMMDeviceCollection_Item(devices, A_Index-1, device) = 0
                if InStr(VA_GetDeviceName(device), m1) && (m2 = "" || ++index = m2)
                    goto VA_GetDevice_Return
                else
                    ObjRelease(device), device:=0

    VA_GetDevice_Return:
        ObjRelease(deviceEnumerator)
        if devices
            ObjRelease(devices)
        
        return device ; may be 0
    }

    VA_IMMDevice_Activate(this, iid, ClsCtx, ActivationParams, ByRef Interface) {
        return DllCall(NumGet(NumGet(this+0)+3*A_PtrSize), "ptr", this, "ptr", VA_GUID(iid), "uint", ClsCtx, "uint", ActivationParams, "ptr*", Interface)
    }

    VA_IAudioClient_GetMixFormat(this, ByRef Format) {
        return DllCall(NumGet(NumGet(this+0)+8*A_PtrSize), "ptr", this, "uint*", Format)
    }

    VA_IAudioClient_Initialize(this, ShareMode, StreamFlags, BufferDuration, Periodicity, Format, AudioSessionGuid) {
        return DllCall(NumGet(NumGet(this+0)+3*A_PtrSize), "ptr", this, "int", ShareMode, "uint", StreamFlags, "int64", BufferDuration, "int64", Periodicity, "ptr", Format, "ptr", VA_GUID(AudioSessionGuid))
    }

    VA_IAudioClient_Start(this) {
        return DllCall(NumGet(NumGet(this+0)+10*A_PtrSize), "ptr", this)
    }

    VA_GetAudioMeter(device_desc="playback")
    {
        if ! device := VA_GetDevice(device_desc)
            return 0
        VA_IMMDevice_Activate(device, "{C02216F6-8C67-4B5B-9D00-D008E73E0064}", 7, 0, audioMeter)
        ObjRelease(device)
        return audioMeter
    }

    VA_GetDevicePeriod(device_desc, ByRef default_period, ByRef minimum_period="")
    {
        defaultPeriod := minimumPeriod := 0
        if ! device := VA_GetDevice(device_desc)
            return false
        VA_IMMDevice_Activate(device, "{1CB9AD4C-DBFA-4c32-B178-C2F568A703B2}", 7, 0, audioClient)
        ObjRelease(device)
        ; IAudioClient::GetDevicePeriod
        DllCall(NumGet(NumGet(audioClient+0)+9*A_PtrSize), "ptr",audioClient, "int64*",default_period, "int64*",minimum_period)
        ; Convert 100-nanosecond units to milliseconds.
        default_period /= 10000
        minimum_period /= 10000    
        ObjRelease(audioClient)
        return true
    }
    ; Convert COM-allocated wide char string pointer to usable string.
    VA_WStrOut(ByRef str) {
        str := StrGet(ptr := str, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "ptr", ptr)  ; FREES THE STRING.
    }
    ; Convert string to binary GUID structure.
    VA_GUID(ByRef guid_out, guid_in="%guid_out%") {
        if (guid_in == "%guid_out%")
            guid_in :=   guid_out
        if  guid_in is integer
            return guid_in
        VarSetCapacity(guid_out, 16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", guid_in, "ptr", &guid_out)
        return &guid_out
    }

    VA_IMMDevice_OpenPropertyStore(this, Access, ByRef Properties) {
        return DllCall(NumGet(NumGet(this+0)+4*A_PtrSize), "ptr", this, "uint", Access, "ptr*", Properties)
    }

    VA_IMMDeviceEnumerator_GetDevice(this, id, ByRef Device) {
        return DllCall(NumGet(NumGet(this+0)+5*A_PtrSize), "ptr", this, "wstr", id, "ptr*", Device)
    }
;}


