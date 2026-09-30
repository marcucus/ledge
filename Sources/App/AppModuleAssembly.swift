import CalendarModule
import ClipboardModule
import Core
import DropZoneModule
import MediaModule
import NotesModule
import ShortcutsModule
import SystemModule
import TimerModule

@MainActor
struct AppModuleAssembly {
    let systemModule = SystemModule()
    let mediaModule = MediaModule()
    let timerModule = TimerModule()
    let dropZoneModule = DropZoneModule()
    let clipboardModule = ClipboardModule()
    let shortcutsModule = ShortcutsModule()
    let calendarModule = CalendarModule()
    let notesModule = NotesModule()

    var navigationModules: [any NotchModule] {
        [
            mediaModule, timerModule, dropZoneModule, clipboardModule,
            shortcutsModule, calendarModule, notesModule,
        ]
    }
}
