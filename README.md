# [Linuxmuser](https://www.linuxmuster.net/de/home/)

## LMv7 walkthrough

Ein Script, um unbegleitetet LinuxMuster v7 zu installieren.

Nutze es mit Vorsicht!

Lasse es nicht auf Rechnern laufen, auf denen wichtige Dinge lagern!

Lasse es als root (!) laufen (das sollte genug über die Gefahren aussagen)!

Das Script erhebt keinen Anspruch auf Vollständigkeit, der Entwickler auch
nicht!

Das Script erwartet ein Debian-basiertes Host-System (Devuan (hierauf ist es
entwickelt und getestet), Debian, Ubuntu, ...).

Der Ablauf läd die VM-Abbilder herunter, dazu und zur Installation benötigt es
erfahrungsgemäß ein rootfs von ca 30GB Größe.

Die Laufwerke der VMs werden in einem LVM abgelegt, hierfür ist genug Platz
vorzusehen (aktuell werden ohne Änderung der voreingestellten Größen ca 135GB
verwendet).

Vor dem Starten des Scriptes ist es hilfreich, es zu lesen, es enthält keine
esoterischen Shell-Konstruktionen und beißt nicht - oben lassen sich sogar ein
paar Einstellungen machen!

Das Script sollte im Wesentlichen als Dokumentation gesehen werden, was zu tun
ist, um LMv7 zu installieren, mehr nicht!

## Weiterer Nutzen

Das Script könnte als "Repeatable Build" für verlässliche Testläufe dienen.

Im LM-Forum gibts eine
[Diskussion](https://ask.linuxmuster.net/t/lm-v7-walkthrough/4552/92) über das
Script und die Unwägbarkeiten in der Installation.

## Ein paar Worte über Verlässlichkeit, Wiederholbarkeit und Korrektheit

Das Script nutzt `expect`, um die initiale Installtion der VMs fernzusteuern.
Das ist ein sehr wackeliges Konstrukt, für das es im Moment keine Alternative
gibt. Die Opnsense Firewall hat garkeine andere dokumentierte Möglichkeit, auf
der Konsole zu arbeiten, es existiert eine Shell, aber nach dem Anmelden
befindet man sich ersteinmal in einem Menü. Opnsense spricht von einer API, die
es gibt. Leider ist diese weder gut Dokumentiert noch vollständig. Ähnlich ist
es mit dem Server, der nach dem Anmelden ausser über die Konsole nicht zu
erreichen ist. Immerhin ist die Architektur von Linuxmuster so, dass die
darunterliegenden Kommandos ausreichen, alle Funktionen zu nutzen (auch wenn
einige für eine Automatisierung wenig geeignet sind).

Auch das "Editieren des XML" der Beschreibungen der VMs könnte in Zukunft zu
Problemen führen, wenn die gelieferten Images andere Einstellungen haben. Hier
gibt es allerdings eine andere Möglichkeit, die VMs aufzusetzen. Nebenbei wird
auch der von Linuxmuster dokumentierte Weg per 'virt-convert' bald obsolet
sein.

Im gesammten System gibt es keine Anker für einer wiederholbare Herstellung
eine Zustandes. Der Ablauf enthält Upgrades der verschiedenen VMs in einen
Zustand, der zeitpunktabhängig ist. Damit hat man mit einem sich wahllos
ändernden System zu tun, in dem die Fehlersuche einer Sisyphos-Arbeit
gleichkommt. Einzelne Funktionen und deren Weiterentwicklung lassen sich so
kaum testen.

Ein Problem für die Automatisierung ist zusätzlich die fehlenden Fehlerabfragen
in den vielen Scripten, die Linuxmuster ausmachen. Für das walkthrough ist dann
nicht mehr erkennbar, ob ein Ablauf überhaupt erfolgreich war.

