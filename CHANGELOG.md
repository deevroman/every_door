# Every Door App Change Log

## 0.5.0

_Unreleased_

* Keeping the map big when there's enough space for POI tiles.
* Fixed type list flicker because of defaults loading slowly.
* Increased minimum rotation angle to 30° to make disabling it easier.
* Quick fix for the entrances mode when the map is rotated:
  not asking for options then.
* Not asking for a roof shape if there are `building:part`s.
* Preventing deletion of nodes that are relation members.
* Not allowing the "address" option on polygonal buildings.
* Removed the "inactive" button for new non-amenities.
* Imagery list in Settings was refreshing constantly.
* Presenting 250 top values for `payment:*` keys.
* Maxar Premium Imagery is back.
* OpenStreetMap layer zoom 19 is back.
* Many, many new translations — thanks folks, and thanks to Weblate.

## 0.4.0

_Released on 2022-05-22_

* Redesigned app navigation (thanks Alexey A for ideas).
* Default locale is English now.
* Fixed issue with storing default payment tags.
* Added zooming buttons to the map when adding an object.
* Added (black) entrances to that map as well.
* Moved `tourism=picnic_site` to the micromapping mode.
* For `shop=yes`, displaying `shop` in a tile, not `yes`.
* Objects with `club=*` did not register and were not uploaded.
* When snapping a new point to a way failed, adding a `fixme` tag to it.
* Added API status panel to entrances and micromapping modes.
* Drawing much more objects on the map for micromapping.
* Fixed the placeholder API error when updating a building
  after adding an entrance to it.
* Maps can be rotated now.
* Improved sorting in the imagery list.
* Italian translation by @ricloy.
* French translation by @paulhenry46.

### Editor

* Added current values to combo options.
* Increased the number of options to 50 for combo panels.
* Case-insensitive search on the combo page.
* Fixed parsing `Su off` in opening hours.
* For the phone field, validation message is yellow, since it's informational.
* Social media tag values are now clickable when they are not in an URL form.
* Proper keyboard replacement for `ref` and other numeric fields.
* Changed the icon for the tags panel.
* Replaced the plus icon with a checkmark for phone and website fields.
* Moving standard fields to the icon labels block.
* Returned the big green "Save" button.

### Entrances Mode

* Allowing addresses with no street, and fixed removing house numbers.
* Added the address form to entrances (click on `+ADDR` button).
* Added a button for opening an editor for an entrance.
* Tapping away from a building / entrance form saves the edits.
* Choose "address" building type to add a building-less address.

## 0.3.0

_Released on 2022-05-09_

* Made the saving button into a small floating one.
* Swapped tracking and mode changing buttons.
* Road names in address forms are also taken from highways.
* Combo options are now not limited to a preset list.
* Removed the setting for `contact:` prefixes.
* Enabled opening links and phone numbers from the editor.
* Long tap on the sharing button on the tags panel to copy the link.
* Added missing translations for the entrances mode.
* Sped up storing elements to the database slightly.
* Displaying all alternative points on the map, not just modified.
* Option to move buttons from right to left.
* Added safe areas to layout.
* Finally caught the offset issue when dragging entrances onto the map.
* Fixed offset in numbers on the map.

## 0.2.0

_Released on 2022-05-03_

* **First public version.**
* Patched `ref`s to be numbers.
* Allowing floors without addresses.
* Removed closed barrier ways and modified roads from the map.
* Won't allow free-form keys that are not popular enough.
* Enforced maximal value length of 255 characters.
* Added sharing button to the raw tags panel.
* Adding `opening_hours` field if an amenity preset doesn't have one.

## 0.1.13

_Released on 2022-05-01_

* Name supports multiple languages now.
* Added "Move" label to the map in the amenity editor.
* White dots in micromapping denote missing major attributes.
* Fixed micromapping crossings and barriers.
* Fixed duplicates in the types list.
* Enlarged hit boxes for building entrances.
* Added a yellow dot to the map chooser for better visibility over dark background.

## 0.1.12

_Released on 2022-04-30_

* Tap on the editor app bar title to change the amenity type.
* Fixed error on submitting a value in a single-value combobox.
* Fixed error catching on async exceptions.
* Disabled editing floors for POI on building contours.
* In the location chooser for a new object, filtering objects by type.
* Added `barrier=*` to micromapping types.
* Once more reduced "big map" distance in the amenity mode.
* Map shows modified objects from other modes, just in case.
* Zoom buttons for the map.

## 0.1.11

_Released on 2022-04-27_

* German translation complete, thanks to @mfbehrens99.
* Fixed an error when upgrading database.
* Made labels column in the floor editor a bit wider.
* Forgot some translations.

## 0.1.10

_Released on 2022-04-27_

* System logs can be sent to the author (tap the version in settings).
* When the database is broken, the app recreates it.
* More roof shapes.
* Option to store flat number for an entrance in `addr:unit`.
* Translated everything.

## 0.1.9

_Released on 2022-04-26_

* Better sorting in the micromapping legend, and a label for "Other".
* Exception catching on loading changes.
* More translated strings.

## 0.1.8

_Released on 2022-04-25_

* Mode switching button is now on the main screen.
* Micromapping mode now has coloured dots instead of tiles and numbers.
* Added app version to the settings screen.
* Fixed location scopes in the app.
* Made hint labels lighter in text fields.
* Button in hours editor to use the most common value from around.
* For a list of default presets, also considering last used presets
  and types of objects around.
* Button to delete all downloaded data in settings.
* Increased re-check interval to 2 weeks.
* Support for landscape screen orientation.
* Fixed a possible deadlock on the loading screen.

## 0.1.7

_Released on 2022-04-22_

* You could press the upload button twice and make duplicates.
* Changing building tags and adding an entrance to it broke uploading.
* Fixed osmChange exporting that broke in the last version.
* Increased zoom in map chooser in the micromapping mode.
* Not adding `check_date` for micromapping objects.
* When renewing an area, deleted elements were not removed from the editor.
* Disabled uploading elements one by one when there are way geometry changes.
* Better error handling when uploading elements one by one.
* After pressing the "manual ref" button in entrance editor, input focus stayed elsewhere.

## 0.1.6

_Released on 2022-04-22_

* Automatic snapping of entrances, tram stops, highway bumps, etc
  to buildings and roads on upload.
* Fixed arrow color and positioning on new entrance drag.
* Images instead of values for `roof:shape`.
* Added a safeguard against changeset comments made too long.

## 0.1.5

_Released on 2022-04-19_

* Redesiged mode buttons in Settings.
* Refactored all mode editors, now the UI is consistent.
* Editable preference for `payment:*` tags.
* `ref` for an entrance can be typed manually.
* Cancelling building or entrance editing did not work.
* Editor displays modified objects only relevant to the current mode.
* Finalized default preset lists for both modes.
* Added submitting buttons to phone and website fields.
* Description, note, and some other fields are now multiline.

## 0.1.4

_Released on 2022-04-16_

* Amenity list is displayed top-down instead of left-right.
* Added a draft version of the micromapping mode (can be enabled in Settings).
* Added a draft version of the building & entrance editor (find it in Settings).
* When your numeric keyboard cannot switch to letters, there's a fix in Settings.
* If you prefer `contact:phone` and `contact:website`, there's a setting.
* `PH off` support for opening hours and few more usability tweaks.
* You can mark an unchanged amenity checked on the editor page.
* Reduced distance for switching into the big map mode.
* Hopefull solved absence of POI on app restore.
* Added `club=*` to supported tags.
* Allowing moving nodes that are relation members.
* Better indication that the map in the editor is just another editable field.

## 0.1.3

_Released on 2022-04-04_

* You can choose an address on a map.
* Button to add a new address if the correct one is missing.
* Added support for Zelenograd addressing (`addr:city` without `addr:place`).
* Failsafe for tapping "back" button in the editor and losing changes.
* Press "back" on the main screen to return to your location.
* When adding a new opening hours fragment, enter the time interval.
* Initial opening hours interval is the most common one around.
* Hours fragments are sorted and de-duplicated on save.
* Current floor is displayed in the editor even without an address.
* Floor filter wasn't updated on address change.
* Fixed normalization in searching ("кофейня" works now).
* Fixed searching by tag values ("bar" works now).
* Fixed certificate error and icon for Android 7.

## 0.1.2

_Released on 2022-03-31_

* Map zooms dynamically only when location tracking is enabled.
* When far away from your geolocation, the map size is increased.
* Invalid phone numbers are now still accepted (e.g. 4-digit short numbers).
* Phone and website values are stored on lost field focus as well.
* Filter for non-verified amenities.
* Map for adding an amenity shows other amenities.
* Search terms are split by words, improving type searching.
* Checkmark hit area is increased vertically.
* Vending machines are displayed now, guideposts are not.
* When restoring the app, POI are updated now.
* App did not remember an object was referenced by another.
* Better error catching when uploading data.
* Fixed uploading modified relations.

## 0.1.1

_Released on 2022-03-30_

* Map zooms dynamically to accomodate all amenities listed.
* Fixed OAuth error with a `FormatException`.
* First upload after app start redirected to the login page.
* Added address and floor filters.
* Added a raw tag editor.
* Pending changes can be deleted from the list by swiping left.
* Uploading conflicts are resolved preemptively by downloading fresh data first.
* Better display for downloading state.
* Now can delete polygon amenities (using `was:` prefix).
* Moved "disused" and "missing" buttons below the fields.
* Removed the "missing" button for freshly created amenities.
* Better message for when there are no POI around.
* Changed app name to "Every Door" from "every\_door".
* Radio buttons stay in place on tap when they fit the screen.
* Removed `building_area` and `opening_hours/covid19` fields.
* Added more emoji for types (thanks @mfbehrens99).
* Types now can be found by tag values.
* It was possible to have an opening\_hours fragment with no weekdays.
* Made an editor for complex opening hours (as a raw string).
* Added address and floor fields to human-less amenities like atms.
* German translation (thanks @mfbehrens99).
* Your location is now updated once every 10 seconds when you don't move.
* With GPS disabled, app now restores the last location.
* Fixed a map error when GPS is off.
* Fixed empty floor list when adding an address to a POI with floor tags.
* Fixed a database error when restoring multipolygon relations.

## 0.1.0

_Released on 2022-03-25_

* First internal testing version.
