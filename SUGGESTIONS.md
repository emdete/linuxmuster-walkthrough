# Empfehlungen

## Vorab

Die Erstellung dieses walkthrough hat mich tief in die Funktion von Linuxmuster
schauen lassen. Im Grunde habe ich in Teilen ein Code-Review vorgenommen.

Die Erkenntnisse daraus habe ich hier in "Empfehlungen" zusammengefasst.

## Fundstücke

Das Passwort wird an LINBO aus der Datei /etc/rsyncd.secrets übertragen. Ist
diese Datei in LINBO nicht verfügbar, erscheint darüber keine Fehlermeldung.
Stattdessen passiert viel später ein Folgefehler.

linbo-ssh sourced `/usr/share/linuxmuster/defaults.sh`, darin wird das
Python-Script `/usr/lib/linuxmuster/constants.py` mit aufwendigem sed-Ausdruck
in Shell-Syntax umgeformt und dann per `eval` eingelesen.

Im `/srv/linbo/lmn-bionic.cloop.postsync` wird mit komplexen sed-Ausdrücken
simples geleistet. Ein kurzes awk-Script täte dasselbe und wäre lesbarer &
wartbarer.

## Check All Errors

Alle Programme und Scripte sollten jeden Fehler erkennen und entsprechend
melden und entweder entsprechend reagieren oder sich beenden.

Shell-Script können mit der Option -e an die Shell gestartet werden, sodass die
Shell das Script beendet, wenn ein Fehler passierte. Die Option -u bewirkt,
dass Nutzung ungesetzter Variablen zum Fehler führen. Darüber hinaus ist `set
-o pipefail` (nur `bash`) hilfreich, da sonst Fehler in Prozessen die in einer
Pipe-Kette ausgeführt werden, ignoriert werden.

In Pythonscripten müssen die Fehler mit jedem Befehl, der keine Exceptions
wirft überprüft werden (os.system ist so ein Funktion, sie wird von linuxmuster
häufig benutzt und fast nie überprüft).

## Fail Early

Es ist gut, früh Fehler zu bemerken und direkt zu melden und den Vorgang
abzubrechen. Das erleichtert die Suche nach der Ursache erheblich.

## Report Truth

Logging ist das A und O von Softwareentwicklung. Die Nachrichten sollten nicht
"lügen" sondern so exakt wir möglich ausdrücken, was da Gerade passiert.
Meldungen auf dem Niveau "Konnte nicht, weil ging nicht" sind wenig hilfreich.

## Reduce

Je kleiner die Scripte sind und je weniger Scripte nötig (kaskadiert) sind,
desdo schneller lassen sich Abläufe und Funktionen erkennen, verstehen und im
Bedarfsfalle korrigieren.

## Structure

Gut structurierte Scripte sind ein Augenschmaus und machen Spass beim Lesen.
Nicht umsonst fordert Python korrekte Formatierung als Element der
Programmiersprache.

