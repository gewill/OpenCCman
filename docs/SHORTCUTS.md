# Shortcuts text conversion (2.1 candidate)

The **Convert Chinese Text** action accepts a text value and one of the four
existing presets, then returns the converted text for the next action. It does
not read or change the text in an open editor. Shortcuts may start the app
process to run the action. The action is free and does not use any of the 12
daily homepage conversions.

The action is available on iOS and iPadOS 16 or later and macOS 13 or later.
OpenCCman itself continues to support iOS and iPadOS 15 and macOS 12; these
older systems simply do not show the action. The text input must be at most
10 MiB when encoded as UTF-8. Empty text returns empty text. A larger input
returns an error; this action does not accept files or perform batch conversion.

## Copy converted clipboard text

1. In Shortcuts, create a shortcut with **Get Clipboard**.
2. Add OpenCCman's **Convert Chinese Text** action. Connect its **Text** input
   to the clipboard result and choose a **Conversion Preset**. The default is
   **OpenCC Traditional**.
3. Add **Copy to Clipboard** and connect it to the conversion result.
4. Put `鼠标台湾` on the clipboard and run the shortcut. The Taiwan preset
   should produce `滑鼠臺灣` in the clipboard.

## Convert shared text

1. Create a shortcut, enable **Show in Share Sheet**, and set its input to
   **Text**.
2. Add **Convert Chinese Text**. Connect **Shortcut Input** to **Text** and
   choose a preset.
3. Add **Copy to Clipboard** or **Save File**, passing the conversion result.
4. Share selected text from another app to this shortcut and verify the next
   action receives the complete result. A source app must itself offer text
   sharing; this action does not replace text in the source app.

For the Taiwan preset, the action uses the same character and idiom rules as
the matching preset in OpenCCman. The Simplified preset does not promise full
reverse conversion of Taiwan-specific vocabulary.
