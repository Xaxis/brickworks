; The Windows installer. tools/release.py build windows makes it with NSIS 3, on Linux:
;
;   makensis -DVERSION=0.16.0 -DVERSION4=0.16.0.0 -DSOURCE=<the release folder>
;            -DOUTFILE=<setup.exe> -DICON=<brickworks.ico> -DINSTALLED=<installed.nsh>
;            [-DSIGN=<command>] brickworks.nsi
;
; It installs for the person running it, with no administrator, the way VS Code's User
; Installer and Obsidian's do: into %LOCALAPPDATA%\Programs\Brickworks unless they choose
; another folder, with Brickworks in the Start menu, a desktop shortcut if they tick it,
; .ldr, .mpd, .io and .lxf opening in it, and an uninstaller that Settings > Apps runs.
; Their models and settings (%APPDATA%\Godot\app_userdata\Brickworks) are never touched.
;
; For the app's updater: setup.exe /VERYSILENT (or NSIS's own /S) installs with no window,
; over the version there, keeping the shortcuts the person chose; it waits up to a minute
; for a running Brickworks to close first, and /LAUNCH starts the app once it is in. Exit
; code 0 means installed. "Uninstall Brickworks.exe" /S removes it the same way.
;
; With SIGN, a command that signs the file named by its last argument in place
; (WINDOWS_SIGN_COMMAND), the uninstaller is signed as it is written and the installer
; once it is made.

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user

!ifdef SIGN
  !finalize '${SIGN}' = 0
  !uninstfinalize '${SIGN}' = 0
!endif

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"

!define APP "Brickworks"
!define EXE "Brickworks.exe"
!define UNINSTALLER "Uninstall Brickworks.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Brickworks"
!define SETTINGS_KEY "Software\Brickworks"
!define CLASSES "Software\Classes"

Name "${APP}"
Caption "${APP} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Brickworks"
InstallDirRegKey HKCU "${SETTINGS_KEY}" "InstallDir"
BrandingText "${APP} ${VERSION} · brickworks.diy"

VIProductVersion "${VERSION4}"
VIAddVersionKey /LANG=0 "ProductName" "${APP}"
VIAddVersionKey /LANG=0 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=0 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=0 "FileDescription" "${APP} ${VERSION} setup"
VIAddVersionKey /LANG=0 "CompanyName" "${APP}"
VIAddVersionKey /LANG=0 "LegalCopyright" "Copyright (c) 2026 ${APP}"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!define MUI_COMPONENTSPAGE_NODESC
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "$(OpenIt)"
!define MUI_UNCONFIRMPAGE_TEXT_TOP "$(KeptText)"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; The site's languages. Windows' own language picks one; English otherwise.
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "Spanish"

LangString WelcomeText ${LANG_ENGLISH} "This installs Brickworks ${VERSION} for you alone: no administrator is needed.$\r$\n$\r$\nThe whole part library comes with it, so building needs no network. Your models and settings are kept apart from the app, and an update or an uninstall leaves them as they are."
LangString WelcomeText ${LANG_GERMAN} "Hiermit wird Brickworks ${VERSION} nur für Sie installiert: Administratorrechte sind nicht nötig.$\r$\n$\r$\nDie ganze Teilebibliothek ist dabei, zum Bauen braucht es also kein Netz. Ihre Modelle und Einstellungen liegen getrennt von der App; ein Update oder eine Deinstallation lässt sie unverändert."
LangString WelcomeText ${LANG_FRENCH} "Ceci installe Brickworks ${VERSION} pour vous seul : aucun administrateur n’est nécessaire.$\r$\n$\r$\nToute la bibliothèque de pièces est incluse : construire ne demande aucun réseau. Vos modèles et vos réglages sont conservés à part de l’application, et une mise à jour ou une désinstallation les laisse tels quels."
LangString WelcomeText ${LANG_SPANISH} "Esto instala Brickworks ${VERSION} solo para ti: no hace falta un administrador.$\r$\n$\r$\nIncluye toda la biblioteca de piezas, así que construir no necesita red. Tus modelos y ajustes se guardan aparte de la aplicación, y una actualización o una desinstalación los deja como están."
LangString OpenIt ${LANG_ENGLISH} "Open Brickworks"
LangString OpenIt ${LANG_GERMAN} "Brickworks öffnen"
LangString OpenIt ${LANG_FRENCH} "Ouvrir Brickworks"
LangString OpenIt ${LANG_SPANISH} "Abrir Brickworks"
LangString DesktopShortcut ${LANG_ENGLISH} "A shortcut on the desktop"
LangString DesktopShortcut ${LANG_GERMAN} "Eine Verknüpfung auf dem Desktop"
LangString DesktopShortcut ${LANG_FRENCH} "Un raccourci sur le bureau"
LangString DesktopShortcut ${LANG_SPANISH} "Un acceso directo en el escritorio"
LangString StillOpen ${LANG_ENGLISH} "Brickworks is open. Close it, then choose Retry."
LangString StillOpen ${LANG_GERMAN} "Brickworks ist geöffnet. Schließen Sie es und wählen Sie dann Wiederholen."
LangString StillOpen ${LANG_FRENCH} "Brickworks est ouvert. Fermez-le, puis choisissez Réessayer."
LangString StillOpen ${LANG_SPANISH} "Brickworks está abierto. Ciérralo y elige Reintentar."
LangString KeptText ${LANG_ENGLISH} "This removes Brickworks from this computer. Your models and settings stay where they are, in %APPDATA%\Godot\app_userdata\Brickworks."
LangString KeptText ${LANG_GERMAN} "Hiermit wird Brickworks von diesem Computer entfernt. Ihre Modelle und Einstellungen bleiben, wo sie sind: in %APPDATA%\Godot\app_userdata\Brickworks."
LangString KeptText ${LANG_FRENCH} "Ceci retire Brickworks de cet ordinateur. Vos modèles et vos réglages restent où ils sont, dans %APPDATA%\Godot\app_userdata\Brickworks."
LangString KeptText ${LANG_SPANISH} "Esto quita Brickworks de este equipo. Tus modelos y ajustes se quedan donde están, en %APPDATA%\Godot\app_userdata\Brickworks."
LangString LdrName ${LANG_ENGLISH} "LDraw model"
LangString LdrName ${LANG_GERMAN} "LDraw-Modell"
LangString LdrName ${LANG_FRENCH} "Modèle LDraw"
LangString LdrName ${LANG_SPANISH} "Modelo LDraw"
LangString MpdName ${LANG_ENGLISH} "LDraw multi-part model"
LangString MpdName ${LANG_GERMAN} "Mehrteiliges LDraw-Modell"
LangString MpdName ${LANG_FRENCH} "Modèle LDraw en plusieurs parties"
LangString MpdName ${LANG_SPANISH} "Modelo LDraw de varias partes"
LangString IoName ${LANG_ENGLISH} "BrickLink Studio model"
LangString IoName ${LANG_GERMAN} "BrickLink-Studio-Modell"
LangString IoName ${LANG_FRENCH} "Modèle BrickLink Studio"
LangString IoName ${LANG_SPANISH} "Modelo de BrickLink Studio"
LangString LxfName ${LANG_ENGLISH} "LDD model"
LangString LxfName ${LANG_GERMAN} "LDD-Modell"
LangString LxfName ${LANG_FRENCH} "Modèle LDD"
LangString LxfName ${LANG_SPANISH} "Modelo LDD"

Var Launch

; Waits for a running Brickworks to let go of its program: a minute when silent (the
; updater has just asked it to close), or until the person closes it.
!macro WaitForClosed UN
Function ${UN}WaitForClosed
  ${IfNot} ${FileExists} "$INSTDIR\${EXE}"
    Return
  ${EndIf}
  StrCpy $R9 0
  ${Do}
    ClearErrors
    FileOpen $R8 "$INSTDIR\${EXE}" a
    ${IfNot} ${Errors}
      FileClose $R8
      Return
    ${EndIf}
    ${If} ${Silent}
      IntOp $R9 $R9 + 1
      ${If} $R9 > 120
        SetErrorLevel 2
        Quit
      ${EndIf}
      Sleep 500
    ${Else}
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(StillOpen)" IDRETRY retry
      Quit
      retry:
    ${EndIf}
  ${Loop}
FunctionEnd
!macroend
!insertmacro WaitForClosed ""
!insertmacro WaitForClosed "un."

; One model type: its own ProgID, so Explorer names it and opens it in Brickworks, and
; Brickworks in the type's Open with. The type's default is set only where nothing has it
; yet: a person with Studio or LDD keeps .io or .lxf opening there.
!macro Associate EXT NAME
  WriteRegStr HKCU "${CLASSES}\Brickworks.${EXT}" "" "$(${NAME})"
  WriteRegStr HKCU "${CLASSES}\Brickworks.${EXT}" "FriendlyTypeName" "$(${NAME})"
  WriteRegStr HKCU "${CLASSES}\Brickworks.${EXT}\DefaultIcon" "" '"$INSTDIR\${EXE}",0'
  WriteRegStr HKCU "${CLASSES}\Brickworks.${EXT}\shell\open\command" "" '"$INSTDIR\${EXE}" "%1"'
  WriteRegStr HKCU "${CLASSES}\.${EXT}\OpenWithProgids" "Brickworks.${EXT}" ""
  WriteRegStr HKCU "${CLASSES}\Applications\${EXE}\SupportedTypes" ".${EXT}" ""
  ReadRegStr $R0 HKCR ".${EXT}" ""
  ${If} $R0 == ""
  ${OrIf} $R0 == "Brickworks.${EXT}"
    WriteRegStr HKCU "${CLASSES}\.${EXT}" "" "Brickworks.${EXT}"
  ${EndIf}
!macroend

!macro Dissociate EXT
  ReadRegStr $R0 HKCU "${CLASSES}\.${EXT}" ""
  ${If} $R0 == "Brickworks.${EXT}"
    DeleteRegValue HKCU "${CLASSES}\.${EXT}" ""
  ${EndIf}
  DeleteRegValue HKCU "${CLASSES}\.${EXT}\OpenWithProgids" "Brickworks.${EXT}"
  DeleteRegKey /ifempty HKCU "${CLASSES}\.${EXT}\OpenWithProgids"
  DeleteRegKey /ifempty HKCU "${CLASSES}\.${EXT}"
  DeleteRegKey HKCU "${CLASSES}\Brickworks.${EXT}"
!macroend

Section "${APP}" SecApp
  SectionIn RO
  Call WaitForClosed
  SetOutPath "$INSTDIR"
  ; Over an earlier Brickworks, its files go first, so none of them outlives the update.
  !include "${INSTALLED}"
  File /r "${SOURCE}\*.*"
  WriteUninstaller "$INSTDIR\${UNINSTALLER}"
  CreateShortcut "$SMPROGRAMS\${APP}.lnk" "$INSTDIR\${EXE}"

  WriteRegStr HKCU "${SETTINGS_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${APP}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://brickworks.diy"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "HelpLink" "https://brickworks.diy/download"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" '"$INSTDIR\${EXE}",0'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALLER}" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0

  WriteRegStr HKCU "${CLASSES}\Applications\${EXE}" "FriendlyAppName" "${APP}"
  WriteRegStr HKCU "${CLASSES}\Applications\${EXE}\shell\open\command" "" '"$INSTDIR\${EXE}" "%1"'
  !insertmacro Associate "ldr" LdrName
  !insertmacro Associate "mpd" MpdName
  !insertmacro Associate "io" IoName
  !insertmacro Associate "lxf" LxfName
  ; SHCNE_ASSOCCHANGED: Explorer shows the new types' names and icons at once.
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

Section /o "$(DesktopShortcut)" SecDesktop
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\${EXE}"
SectionEnd

; Inno Setup's /VERYSILENT, which the updater and most deployment tools say, is NSIS's /S.
Function .onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/VERYSILENT" $R1
  ${IfNot} ${Errors}
    SetSilent silent
  ${EndIf}
  ClearErrors
  ${GetOptions} $R0 "/LAUNCH" $R1
  ${IfNot} ${Errors}
    StrCpy $Launch 1
  ${EndIf}
  ; A desktop shortcut the person made last time is ticked again, and so kept.
  ${If} ${FileExists} "$DESKTOP\${APP}.lnk"
    !insertmacro SelectSection ${SecDesktop}
  ${EndIf}
FunctionEnd

Function un.onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/VERYSILENT" $R1
  ${IfNot} ${Errors}
    SetSilent silent
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  ${If} ${Silent}
  ${AndIf} $Launch == 1
    Exec '"$INSTDIR\${EXE}"'
  ${EndIf}
FunctionEnd

Section "Uninstall"
  Call un.WaitForClosed
  Delete "$SMPROGRAMS\${APP}.lnk"
  Delete "$DESKTOP\${APP}.lnk"
  ; Only what the installer put there: never the rest of a folder someone chose.
  !include "${INSTALLED}"
  Delete "$INSTDIR\${UNINSTALLER}"
  RMDir "$INSTDIR"
  !insertmacro Dissociate "ldr"
  !insertmacro Dissociate "mpd"
  !insertmacro Dissociate "io"
  !insertmacro Dissociate "lxf"
  DeleteRegKey HKCU "${CLASSES}\Applications\${EXE}"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "${SETTINGS_KEY}"
SectionEnd
