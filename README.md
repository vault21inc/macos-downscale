# Downscale Images for Finder

Adds **Downscale Images** to Finder's **Quick Actions** menu for selected image files. It asks for the maximum width or height in pixels, prefilled with **1920**, then uses macOS `sips -Z` to fit each image within that limit while keeping its aspect ratio. Images already within the limit are skipped. Originals are never changed.

For each source folder containing selected images, the action creates a new folder beside those images named with the current local timestamp, such as `2026-10-21_14-30-05`. Resized copies go inside it as `photo-1920px.jpg`, `photo-1920px-2.jpg`, and so on. Selected images from the same source folder share one timestamp folder. If that name already exists, the action waits for the next second to avoid mixing runs. It removes an output folder if no image was successfully saved in it.

## Install

Uses macOS's built-in Automator, AppleScript, and `sips`; no package manager or extra app is needed.

```bash
cd /Users/thedaego/development/macos/downscale
./scripts/install.sh
```

Select one or more images in Finder, right-click, and choose **Quick Actions > Downscale Images**. Enter any whole number from 1 to 30000 in the dialog, or accept 1920. The action shows a summary when it finishes. If Finder does not show it immediately, relaunch Finder or log out and back in.

The installed `~/Library/Services/Downscale Images.workflow` contains its own copy of the shell script. You can move or remove this project after installation without breaking the installed action.

## Change the default

Edit `DEFAULT_MAX_PIXELS=1920` near the top of `scripts/downscale.sh`, then run `./scripts/install.sh` again to rebuild and reinstall the action. The dialog still lets you choose a different limit for each run.

## Files and macOS changes

- `scripts/downscale.sh` is the editable source and can be tested without Finder.
- `scripts/build_workflow.py` embeds that source into `dist/Downscale Images.workflow`, a standard Automator Quick Action you can open in Automator.
- The installer copies that workflow to `~/Library/Services/Downscale Images.workflow` and enables its entry in the current user's `pbs` Services preferences (`NSServicesStatus`). It requests a Services cache refresh. It leaves other Quick Actions in place.
- The installer adds no login item, background process, app in `/Applications`, or third-party dependency. Running the action creates timestamp folders beside the selected images and temporary hidden output files inside them. Temporary files are removed after each image completes or fails; a force quit could leave one behind.

The Quick Action is offered for Finder images. `sips` may be able to read an image format without being able to write it; the action reports such files as failures and leaves the originals untouched. In particular, test animated or specialized formats before relying on the result.

## Command-line test

```bash
./scripts/downscale.sh --max-pixels 1920 "/path/to/photo.jpg"
```

Look for `photo-1920px.jpg` in the new timestamp folder beside the original, then use `sips -g pixelWidth -g pixelHeight` on that copy to inspect its size.

## Remove

Move `~/Library/Services/Downscale Images.workflow` to Trash. Its saved `pbs` preference entry may remain, but it has no action to launch without the workflow.
