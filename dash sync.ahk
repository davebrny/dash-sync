/*
[script info]
version     = 0.1
description = folder sync for the bragi dash pro
author      = davebrny
ahk version = 1.1.26.01
source      = https://github.com/davebrny/dash-sync


[settings]
local_folder=
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

iniRead, local_folder, % a_lineFile, settings, local_folder
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
        {
        menu, tray, icon, dash sync b.ico   ; show red tray icon
        if (fileExist(a_loopFileFullPath) = "D")    ; if folder
            fileRemoveDir, % a_loopFileFullPath, 1
        else if a_loopFileExt in % file_types       ; if file
            fileDelete, % a_loopFileFullPath
        }
    }

loop, files, % local_folder "\*.*", FDR
    {
    if inStr(a_loopFileFullPath, "\.sync")
        continue    ; ignore resilio sync
    stringReplace, dash_item, % a_loopFileFullPath, % local_folder, % dash_folder
    if !fileExist(dash_item)    ; if not on the dash's drive, then create or copy
        {
        menu, tray, icon, dash sync b.ico
        if (fileExist(a_loopFileFullPath) = "D")
            fileCreateDir, % dash_item
        else if a_loopFileExt in % file_types
            fileCopy, % a_loopFileFullPath, % dash_item
        }
    }
menu, tray, icon, dash sync.ico  ; reset icon
return
