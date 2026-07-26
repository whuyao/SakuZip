# YCompress User Guide

## Interface

YCompress has four areas:

- **Compress & Extract**: add items, choose a workflow, and run the queue.
- **Workflows**: use built-in workflows or create custom ones.
- **History**: view completed items from the current App session.
- **Settings**: change the output folder and review supported formats.

All processing stays on this Mac. No account is required and no file is
uploaded. The [UrbanComp team website](https://urbancomp.net) is available from
the sidebar, Settings, and Help menu.

## Interface language

YCompress supports Simplified Chinese, English, and Japanese. The first launch
follows the macOS preferred language. You can then choose Follow System or a
specific language in **YCompress Settings → Language**. The choice is stored
locally and applies after restarting the App, including future launches.

## Add files

Use any of these methods:

1. Drop files or folders onto the dashed area.
2. Click **Choose Files…**.
3. Click **Add Files** in the upper-right corner.
4. Choose **File → Add Files…** or press `Command-O`.
5. In Finder, right-click a file and choose **Open With → YCompress**.
6. Drop one or more files onto the `YCompress.app` icon.

The queue can mix images, video, regular files, folders, and archives. The same
path is not added twice.

If an iCloud Drive or other cloud-backed file has not downloaded yet, its size
is shown as **Size pending (cloud file downloading)**. YCompress re-reads the
source size during processing and calculates the saving or increase only after a
positive, current size is available.

Files opened externally are added to the waiting queue, but processing does not
start automatically. Choose a workflow, check the output folder, and click
**Run Workflow**.

## Smart Compression

Smart Compression is the default workflow:

- Images are resized and re-encoded with ImageIO.
- Video is exported to MP4 with a compatible AVFoundation preset.
- Regular files, folders, and archives are packaged into a new ZIP.

Smart Compression does not extract an existing archive. Choose **Safe
Extraction** when you want to extract one.

Basic steps:

1. Add one or more items.
2. Select **Smart Compression**.
3. Confirm the output folder.
4. Click **Run Workflow**.
5. When complete, click the magnifying-glass button to show the result in Finder.

## Image compression

The built-in **Web Images** workflow:

- Limits the longest edge to 1920 px.
- Outputs JPEG by default.
- Uses Balanced quality.

JPEG, PNG, HEIC, HEIF, TIFF, BMP, GIF, and WebP are recognized, but actual
decoding support depends on the installed macOS version. Animated GIF and WebP
files may be reduced to their first frame. To preserve transparency, choose
Automatic or PNG instead of forcing JPEG.

## Video compression

The built-in **Share Video** workflow first compares the source video with the
estimated output sizes of system presets. It chooses the highest-quality
compatible preset expected to reduce the file. Output is MP4 and is optimized
for network playback by default.

Resolution choices:

- **Keep Original Resolution**: use the system's highest-quality preset.
- **Up to 1080p**: choose among compatible presets no larger than 1080p.
- **Up to 720p**: choose among compatible presets no larger than 720p.
- **Up to 540p**: choose among compatible presets no larger than 540p.

High Quality, Balanced, and Smaller Size set different estimated output limits.
If the actual export is not smaller than the source, YCompress deletes that
result and reports the problem. Exact bitrate, CRF, audio tracks, subtitles, and
encoder selection are not currently exposed. MKV, WebM, or unusual codecs may
fail when AVFoundation cannot decode them.

## Archive files and folders

Choose **Create Archive**, or use Smart Compression with a regular item:

- Each queue item produces its own ZIP.
- A folder can retain its top-level folder name.
- A single file is placed at the ZIP root.
- macOS resources and extended metadata can be preserved.
- Existing output is not overwritten; `2`, `3`, and so on are added as needed.

Combining several separate queue items into one ZIP is not currently supported.

## Safe extraction

Supported formats:

- ZIP
- TAR
- TGZ
- TAR.GZ

YCompress checks all archive entry paths before extraction and rejects absolute
paths and paths containing `..`, reducing Zip Slip risk. 7z, RAR, and single-file
GZ are not supported.

## Custom workflows

1. Open **Workflows**.
2. Click **New Workflow**.
3. Enter a name.
4. Choose an action and quality.
5. Click **Create**.
6. Click **Use** on the workflow card to return to the processing screen.

Custom workflows are saved in local preferences. Deleting one does not delete
any output files.

## Advanced workflow settings

Click the sliders button on a workflow card. Built-in workflows can also be
adjusted and restored with **Restore Defaults**.

All workflows support:

- Output filename suffix.
- Show in Finder after completion.
- Continue or stop the queue after one item fails.

Image options:

- Output format: Automatic, JPEG, PNG, or HEIC.
- Quality: High Quality, Balanced, or Smaller Size.
- Optional longest-edge limit from 512 to 8192 px.

Video options:

- Output resolution: original, 1080p, 720p, or 540p.
- Network playback optimization.
- Quality level controlling the estimated output-size limit.

ZIP options:

- Keep the top-level folder.
- Preserve macOS resources and extended metadata.

Extraction options:

- Create a separate folder for each archive.
- When disabled, write directly into the output folder. Same-name items may be
  replaced, so use this option carefully.

## Output folder

Before files are added, the initial folder is:

```text
~/Downloads/YCompress
```

When the first batch is added, the destination changes to the folder containing
the first source file. For a source folder, its parent folder is used so the ZIP
is not written inside the folder being archived. Items from multiple folders use
the first item's source folder.

Use the folder button in the bottom bar or Settings to choose another
destination. Adding more files to an existing queue does not override a folder
you selected manually. Same-name output is not overwritten.

## Queue status and controls

- **Waiting**: not started.
- **Processing**: shows a per-file percentage and processing stage.
- **Completed**: output was created, with progress at 100%.
- **Failed**: shows the error.
- **Cancelled**: retains the percentage reached before cancellation.

**Pause Queue** pauses after the current file safely finishes. **Resume Queue**
continues with the next item. **Cancel** cancels an active video export or
terminates the ZIP/extraction process; image work stops at the next processing
checkpoint.

Pause is intentionally applied between items because ImageIO, AVFoundation
exports, and system archive tools do not all support reliable in-place
suspension. This avoids damaged or partial output.

The magnifying-glass button resolves the latest output by task ID. Files are
selected in Finder and extracted folders are opened directly. **Clear Results**
removes completed, failed, and cancelled rows from the interface without
deleting files.

## Troubleshooting

### Video export fails

Check whether the source plays in QuickTime Player. If QuickTime cannot open it,
AVFoundation probably does not support its codec.

### The compressed file becomes larger

Already-compressed images and ZIP files may become larger after reprocessing and
are shown in red. Video is analyzed before export, and a video output that is
not smaller than the source is deleted automatically.

### RAR or 7z cannot be extracted

macOS does not include their decoders and YCompress does not bundle third-party
executables in the current release.

### History disappears

History is retained only for the current App session. Quitting YCompress does
not delete output files.

### Are files uploaded?

No. YCompress itself performs no network requests and all processing is local.
