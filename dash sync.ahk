/*
[script info]
version     = 0.4
description = folder sync for the bragi dash pro
author      = davebrny
ahk version = 1.1.26.01
source      = https://github.com/davebrny/dash-sync


[settings]
local_folder=
show_transfer=true
close_after=false
show_warning=true
ignore_pattern=\.sync,playlist x
*/

#noEnv
#singleInstance, force
#persistent
setWorkingDir, % a_scriptDir

menu, tray, useErrorLevel
menu, tray, icon, dash sync.ico
start_with_windows(1)

global d, the_dash, watching, local_folder
file_types := "mp3,m4a"

iniRead, show_transfer,  % a_lineFile, settings, show_transfer
iniRead, close_after,    % a_lineFile, settings, close_after
iniRead, show_warning,   % a_lineFile, settings, show_warning
iniRead, ignore_pattern, % a_lineFile, settings, ignore_pattern
iniRead, local_folder,   % a_lineFile, settings, local_folder
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
local_list := list_files(local_folder "\*.*")
dash_list  := list_files(the_dash ":\My Music\*.*")
    ; substitute the parent directory of the dash with that of the local
local_list_sub := strReplace(dash_list, dash_folder, local_folder)

if (local_list != local_list_sub)
    {
    goSub, get_file_changes
    goSub, process_changes
    }
goSub, sync_complete
return


list_files(folder_path) {
    global ignore_pattern, file_types
    loop, files, % folder_path, FDR
        {
        if a_loopFileFullPath contains %ignore_pattern%
            continue
        if (a_loopFileExt = "") or inStr(file_types, a_loopFileExt)
            file_list .= a_loopFileFullPath "`n"  ; only add folders and supported file types
        }
    sort, file_list
    return file_list
}


get_file_changes:
changes := []
loop, parse, % local_list, `n
    {                              ; substitute local directory with the dash's
    stringReplace, this_loop, % a_loopField, % local_folder, % dash_folder
    if !inStr(dash_list, this_loop)   ; if file not in the correct place in the dash 
        {
        splitPath, % this_loop, filename, dash_dir
        stringReplace, local_dir, % dash_dir, % dash_folder, % local_folder
        if inStr(dash_list, "\" filename)    ; check if the file is elsewhere on the dash
            {
            fileGetSize, file_size, % local_dir "\" filename
            found_path := get_path(dash_list, filename, file_size)
            changes.push([ "move" , found_path , dash_dir "\" filename ])   ;# move
            move_list .= found_path "`n"
            }
        else changes.push([ "copy" , local_dir "\" filename , this_loop ])  ;# copy
        }
    }

loop, parse, % local_list_sub, `n
    {
    if !inStr(local_list, a_loopField)  ; if file on the dash but no longer in the local folder
        {
        splitPath, % a_loopField, filename, local_dir
        stringReplace, dash_dir, % local_dir, % local_folder, % dash_folder
        if inStr(move_list, dash_dir "\" filename)
            continue ; if this file is going to be moved
        changes.push([ "delete", dash_dir "\" filename ])    ;# delete
        ++delete_index
        }
    }
return



get_path(file_list, filename, file_size) {   ;# find a file that has been moved to another folder
    strReplace(file_list, filename, "", file_count)
    loop % file_count    ; in case there are duplicate filenames
        {
        stringGetPos, pos, file_list, % filename, % "L" a_index
        stringMid, text_left, file_list, pos + strLen(filename), , L
        stringGetPos, pos, text_left, `n, R1
        stringMid, path, text_left, pos + 2

        fileGetSize, this_size, % path   ; narrow the changes of matching the wrong file
        if (this_size = file_size) 
            return match := path
        }
    until (match)
}


show_changes:
change_list := ""
loop, % changes.maxIndex()
    {
    change_list .= (changes[a_index].1 = last ? "`n" : "`n`n") 
                .   changes[a_index].1 " - " changes[a_index].2  
                .  (changes[a_index].3 ? ("`nto     " changes[a_index].3) : "")
    last := changes[a_index].1
    }
msgBox, % clipboard := change_list
return


process_changes:
; goSub, show_changes
delete_files := true
if (delete_index) and (show_warning = "true")
    {
    msg := delete_index " files are about to be moved or deleted.`ndo you want to continue?`n`n"
        . "(set 'show_warning' to 'false' to hide this warning)"
    msgBox, 4, , % msg
    ifMsgBox, no
         delete_files := false
    }

change_icon("dash sync b.ico")   ; show red 'busy' icon
loop, % changes.maxIndex()
    {
    action := changes[a_index].1
    source := changes[a_index].2
    dest   := changes[a_index].3
    splitPath, % source, filename
    splitPath, % dest, , directory
    if !fileExist(directory)
        fileCreateDir, % directory

    if (action = "copy")
        {
        goSub, transfer_gui   ; show transfer window
        if (fileExist(source) = "D") ; if folder
            fileCreateDir, % dest
        else ; if file
            {
            guiControl, text, title_text, transferring:
            guiControl, text, transfer_file, % filename
            menu, tray, tip, % "transferring: " filename
            fileCopy, % source, % dest
            }
        }
    else if (action = "move")
        {
        guiControl, text, title_text, moving:
        guiControl, text, transfer_file, % filename
        fileMove, % source, % dest
        }
    else if (action = "delete") and (delete_files = true)
        {
        guiControl, text, title_text, deleting:
        guiControl, text, transfer_file, % filename  
        if (fileExist(source) = "D")
             fileRemoveDir, % source, 1
        else fileDelete, % source
        }  
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


sync_complete:
dash_list := ""
local_list := ""
local_list_sub := ""
changes := ""
delete_index := ""
move_list := ""
guiControl, text, title_text, sync complete
guiControl, text, transfer_file,
change_icon("dash sync.ico")   ; reset icon
menu, tray, tip, % a_scriptName
sleep 5000
if (close_after = "true")
    winClose, dash sync ahk_class AutoHotkeyGUI
return
