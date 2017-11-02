/*
[script info]
version     = 0.3
description = folder sync for the bragi dash pro
author      = davebrny
ahk version = 1.1.26.01
source      = https://github.com/davebrny/dash-sync


[settings]
local_folder=
show_transfer=true
show_warning=true
*/

#noEnv
#singleInstance, force
#persistent
setWorkingDir, % a_scriptDir

menu, tray, useErrorLevel
menu, tray, icon, dash sync.ico
start_with_windows(1)

global the_dash, watching, local_folder
file_types := "mp3,m4a"

iniRead, show_transfer, % a_lineFile, settings, show_transfer
iniRead, show_warning,  % a_lineFile, settings, show_warning
iniRead, local_folder,  % a_lineFile, settings, local_folder
if (local_folder = "")
    goSub, folder_setup

if (the_dash := dash_drive())
    goSub, dash_connected

onMessage(0x219, "usb_detected")    ; 0x219 = WM_DEVICECHANGE

return ; end of auto-execute ---------------------------------------------------









folder_setup:    ;# set up local folder and create playlist sub-folders
regRead, music_folder, HKCU, Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders, My Music
fileSelectFolder, new_folder, *%music_folder%, , Choose a folder to sync to The Dash
if (new_folder)
    {
    run, % new_folder    ; open/focus folder
    iniWrite, % new_folder, % a_lineFile, settings, local_folder
    loop, 4   ; create playlist folders
        {
        if !fileExist(new_folder "\Playlist " a_index)
            fileCreateDir, % new_folder "\Playlist " a_index
        }
    local_folder := new_folder
    }
return



dash_drive(byRef drive_label="") {    ;# return the dash's drive letter
    driveGet, drive_list, list, REMOVABLE
    loop, parse, % drive_list
        {
        driveGet, drive_label, label, %a_loopField%:
        if inStr(drive_label, "DASH") and if fileExist(a_loopField ":\My Music")
            return drive_letter := a_loopField
        }
    until (drive_letter)
}


usb_detected() {
    sleep 500
    the_dash := dash_drive()
    if (the_dash) and (watching != true)
        goSub, dash_connected
    else if (the_dash = "") and (watching = true)
        goSub, dash_disconnected
}


dash_connected:
watching := true
if (dash_folder = "")
    dash_folder := the_dash ":\My Music"
goSub, sync_dash    ; (sync once, then wait for changes)
watchFolder(local_folder, "ccchanges", true, "0x03")
return


dash_disconnected:
watching := false
watchFolder("**END", "1")
return


ccchanges(directory, changes) {   ;# trigger sync on any new or renamed file/folder
    goSub, sync_dash
}



sync_dash:    ;# make the dash's on-board storage match the local folder
loop, files, % the_dash ":\My Music\*.*", FDR
    {
    stringReplace, local_item, % a_loopFileFullPath, % dash_folder, % local_folder
    if !fileExist(local_item)    ; if not in the local folder, then remove
        delete_list .= a_loopFileFullPath "`n"
    }

loop, files, % local_folder "\*.*", FDR
    {
    if inStr(a_loopFileFullPath, "\.sync")
        continue    ; ignore resilio sync
    stringReplace, dash_item, % a_loopFileFullPath, % local_folder, % dash_folder
    if !fileExist(dash_item)    ; if not on the dash's drive, then create or copy
        {
        change_icon("dash sync b.ico")   ; show red 'busy' icon
        if (fileExist(a_loopFileFullPath) = "D")
            fileCreateDir, % dash_item
        else if a_loopFileExt in % file_types
            {
            goSub, transfer_gui   ; show transfer window
            guiControl, text, title_text, transferring:
            guiControl, text, transfer_file, % a_loopFileName
            fileCopy, % a_loopFileFullPath, % dash_item
            }
        }
    }

if (delete_list)
    {
    if (show_warning = "true")
        {
        strReplace(delete_list, "`n", "", item_count)
        msg := item_count " files are about to be deleted from the dash.`n"
            . "do you want to continue?`n`n"
            . "(set 'show_warning' to 'false' to delete files without asking)"
        msgBox, 4, , % msg
        ifMsgBox, yes
            goSub, delete_files
        }
    else goSub, delete_files  ; delete without warning
    delete_list := ""
    }

guiControl, text, title_text, sync complete
guiControl, text, transfer_file,
change_icon("dash sync.ico")   ; reset icon
return



delete_files:    
change_icon("dash sync b.ico")
loop, parse, % delete_list, `n,
    {
    splitPath, % a_loopField, filename, , file_ext
    guiControl, text, title_text, deleting:
    guiControl, text, transfer_file, % filename  
    if (fileExist(a_loopField) = "D")    ; if folder
        fileRemoveDir, % a_loopField, 1
    else if file_ext in % file_types     ; if file
        fileDelete, % a_loopField
    }
return



change_icon(icon_name) {
    menu, tray, icon, % icon_name
    h_icon := dllCall("LoadImage", uint, 0, str, icon_name, uint, 1, int, 0, int, 0, uint, 0x10)
    gui +lastFound
    sendMessage, 0x80, 0, h_icon   ; set window title icon
    sendMessage, 0x80, 1, h_icon   ; set taskbar icon
}


transfer_gui:
if (show_transfer = "true") and !winExist("dash sync ahk_class AutoHotkeyGUI")
    {
    gui, destroy
    gui, font, s11, consolas
    gui, add, text, x10 y10 w350 vtitle_text, transferring:
    gui, font, s14, consolas
    gui, add, text, x10 y45 w450 vTransfer_file,
    gui, show, w450 h100, dash sync
    winSet, transparent, 250, dash sync
    }
return

guiClose:
guiEscape:
gui, destroy
return
