ECHO OFF
DEL prescription_log.txt
ECHO Willkommen zur Ausstellung eines E-Rezepts
TIMEOUT /t 1 /nobreak > NUL
ECHO Dieses Programm basiert auf der ERPione Testmoeglichkeit der gematik. Das Batchfile wird durch den PKV-Verband bereitgestellt
ECHO Skript-Version 2.1 vom 02.07.2025
ECHO ERPione Version:
.\erpione-win.exe --version
TIMEOUT /t 2 /nobreak > NUL

:timeout_input
set /p ERPIONE_REQ_TIMEOUT=Bitte gib an, wie lange das Client-Timeout eingestellt sein soll (Empfehlung 120 Sekunden). Bitte nimm die Eingabe als ganzzahligen Wert zwischen 60 und 300 vor: 

:: Bereich prüfen

if %ERPIONE_REQ_TIMEOUT% LSS 60 (
    echo Der Wert ist zu klein. Bitte mindestens 60 eingeben.
    goto timeout_input
)

if %ERPIONE_REQ_TIMEOUT% GTR 300 (
    echo Der Wert ist zu gross. Maximal 300 erlaubt.
    goto timeout_input
)

echo Das Client-Timeout ist nun auf %ERPIONE_REQ_TIMEOUT% Sekunden eingestellt

:CHECK_AGAIN
set task_id=EMPTY
set AccessCode=EMPTY

echo Welche Art von Verordnung moechtest du ausstellen?
echo [1] Einfachverordnung.xml
echo [2] Mehrfachverordnung.xml
echo [3] Parenterale_Zytostatika.xml
set /P PRESCRIPTION_CHOICE=Bitte Zahl eingeben (1-3): 

if "%PRESCRIPTION_CHOICE%"=="1" set PRESCRIPTION_TYPE=Einfachverordnung.xml
if "%PRESCRIPTION_CHOICE%"=="2" set PRESCRIPTION_TYPE=Mehrfachverordnung.xml
if "%PRESCRIPTION_CHOICE%"=="3" set PRESCRIPTION_TYPE=Parenterale_Zytostatika.xml

if not defined PRESCRIPTION_TYPE (
    echo Ungueltige Eingabe. Bitte triff eine Auswahl.
    GOTO CHECK_AGAIN
)

ECHO Hast du in der E-Rezept Datei die KVNR ueberprueft und das gewuenschte Medikament hinterlegt? 
TIMEOUT /t 2 /nobreak > NUL
SET /P AREYOUSURE=Ich bin E-Rezept-READY! (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO CHECK_AGAIN
ECHO Okay, dein E-Rezept wird jetzt ausgestellt.
TIMEOUT /t 1 /nobreak > NUL

.\erpione-win.exe prescribe -e ru .\%PRESCRIPTION_TYPE% >> prescription_log.txt 2>&1
for /f "tokens=10" %%a in ('findstr /c:"Task-ID" prescription_log.txt') do (
    set task_id=%%a
)
ECHO Task-ID: %task_id%
for /f "tokens=13" %%a in ('findstr /c:"AccessCode" prescription_log.txt') do (
    set AccessCode=%%a
)
ECHO AccessCode: %AccessCode%

ECHO Wurde hier eine Task-ID und ein AccessCode angezeigt und ist das E-Rezept in deiner Testapp angekommen? 
SET /P AREYOUSURE=Ja, ich kann Task-ID, AccessCode und das Rezept sehen (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO RETRY_OFFER

ECHO Super! Moechtest du das Rezept auch gleich einloesen?
SET /P AREYOUSURE=Ja, ich moechte das Rezept einloesen. (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO KEEP_LOG
ECHO Okay, dein Rezept wird nun in zwei Schritten eingeloest. Zunaechst wird es von einer Apotheke angenommen (akzeptiert) und dann dispensiert.

:RETRY_ACCEPT
.\erpione-win.exe accept --taskid %task_id% --accesscode %AccessCode% -e ru >> prescription_log.txt 2>&1

: : secret speichern, falls für dispense Schritt später notwendig. Muss aber noch gecleaned werden, weil Anführungszeichen mitgespeichert werden
for /f "tokens=20" %%a in ('findstr /c:"secret" prescription_log.txt') do (
    set secret=%%a
)


SET /P AREYOUSURE=Wird das Rezept in der App als in Einloesung angezeigt? (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO RETRY_ACCEPT

ECHO Dein E-Rezept wurde nun von der Apotheke angenommen. Du hast nun bis zu 2 Minuten Zeit das Ergebnis zu kontrollieren, bevor das Rezept dispensiert wird. Mit einer beliebigen Taste wird das Rezept sofort dispensiert. 
TIMEOUT /t 120
ECHO Das Rezept wird nun dispensiert.
.\erpione-win.exe dispense --taskid %task_id% -e ru >> prescription_log.txt 2>&1
ECHO Dein E-Rezept ist nun auch dispensiert. Bitte kontrolliere das Ergebnis in der App. Mit einer beliebigen Taste geht es weiter. 
PAUSE
SET /P AREYOUSURE=Moechtest du nun auch gleich einen Kostenbeleg fuer das Rezept erstellen? (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO KEEP_LOG
:RETRY_CHARGE_ITEM
ECHO Der Kostenbeleg wird nun erstellt. 
.\erpione-win.exe chargeitem create --taskid %task_id% .\charge_item.json -e ru >> prescription_log.txt 2>&1

SET /P AREYOUSURE=Falls der Kostenbeleg nicht in der App angekommen ist: Moechtest du es noch mal probieren? (Y/[N])?
IF /I "%AREYOUSURE%" == "Y" GOTO RETRY_CHARGE_ITEM
IF /I "%AREYOUSURE%" == "N" GOTO KEEP_LOG

:KEEP_LOG
ECHO Moechstest du das Log zu diesem Testdurchlauf loeschen (Empfohlen, wenn ein Fehler aufgetreten ist)? 
SET /P AREYOUSURE= Log loeschen? (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO LAST_STEP
DEL prescription_log.txt
:LAST_STEP
SET /P AREYOUSURE= Moechtest du ein weiteres Rezept ausstellen und von vorne beginnen? (Y/[N])?
IF /I "%AREYOUSURE%" == "Y" GOTO CHECK_AGAIN
IF /I "%AREYOUSURE%" == "N" GOTO END


:RETRY_OFFER
SET /P AREYOUSURE=Schade, anscheinend ist etwas schiefgelaufen. Moechtest du es noch einmal probieren? (Y/[N])?
IF /I "%AREYOUSURE%" == "Y" GOTO CHECK_AGAIN
IF /I "%AREYOUSURE%" NEQ "Y" GOTO KEEP_LOG