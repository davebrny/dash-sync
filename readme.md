## dash sync

this is a basic 1-way sync from a local folder to the bragi dash's on-board storage

the idea is that you dont touch any of the files on the dash and instead manage everything from the local folder, only plugging in the dash when you want to update any changes

the benefit of this is that you can sync the folder between your computer(s) and your phone and then add and remove tracks/podcasts as you need to instead of only being able to manage things while the dash is plugged in

im using resilio to sync the local folder over my network but a web based sync like dropbox would give you the added benefit of being able to add/remove tracks from anywhere with an internet connection.

&nbsp;

> note: ive only been using the dash for a week or so and havnt got to do a whole lot of testing with this script yet so proceed with caution!

> there are also plenty of other free syncing tools available such a synctoy that will do the same thing and probably do it more reliably

&nbsp;



### usage

**folder setup**  

when the script runs first you will be asked to select the location of the local folder.  the 4 playlists folders will be created if they havnt been already


**delete warning**  

a warning will show when files are about to be deleted from the dash. this is mainly just to stop all your files on the dash being deleted if your local folder is empty the first time you run the script.
to turn this off, set `show_warning` to `false`

> the number of files being deleted also includes any files that have been renamed


**pausing the script**  

if you end up putting some tracks directly onto the dash from another location, then connect it to a computer thats running this script, those files will be deleted from the dash since they dont match whats in the local folder.  in these cases make sure to pause the script before you plug in the dash:

- right click on the tray icon and select "pause this script" (or just exit/close the script)
- copy the new files to the same place in the local folder so that both folders match
- un-pause or reload the script to turn the sync back on

alternatively, if there is a folder called "playlist x" on the dash then any files placed inside this folder will be ignored by this script and wont be deleted


**ignore patterns**  

if you want a folder to be ignored on the dash or the local folder then add the name of the folder to the 'ignore_pattern' list at the top of the file
```
ignore_pattern = folder name 1,\folder 2,\folder 3\
```
> you can use \ on one or both sides of the name to narrow down the chances of a file being ignored because it has the same name


**start with windows**  

just run the script as you need it or if you want it waiting for whenever you plug in the dash then right click on the tray icon a select "start with windows" to create a startup link


**renaming files**  

every time a file is renamed it will be copied from scratch to the dash's storage. the file transfer is very slow so its best to get any renaming done before you have the dash connected.


**dash pro vs original dash**  

ive only tested this with the dash pro but im presuming the original dash is set up pretty much the same.
if usb drive label has the word "DASH" in it then it should still detect the dash being plugged in
