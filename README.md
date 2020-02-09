# [Linuxmuser]()

## LMv7 walkthrough

Ein Script, um unbegleitetet LinuxMuster v7 zu installieren.

Nutze es mit Vorsicht!

Lasse es nicht auf Rechnern laufen, auf denen wichtige Dinge lagern!

Lasse es als root (!) laufen (das sollte genug über die Gefahren aussagen)!

Das Script erhebt keinen Anspruch auf Vollständigkeit, der Entwickler auch
nicht!

Das Script erwartet ein Debian-basiertes Host-System (Debian, Ubuntu, Devuan
(hierauf ist es entwickelt und getestet)).

Der Ablauf läd die VM-Abbilder herunter, dazu und zur Installation benötigt es
erfahrungsgemäß ein rootfs von 30GB Größe.

Die Laufwerke der VMs werden in einem LVM abgelegt, hierfür ist genug Platz
vorzusehen (aktuell werden ohne Änderung der voreingestellten Größen 135GB
verwendet).

Vor dem Starten des Scriptes ist es hilfreich, es zu lesen, es enthält keine
esoterischen Shell-Konstruktionen und beisst nicht - oben lassen sich sogar ein
paar Einstellungen machen!

Das Script sollte im Wesentlichen als Dokumentation gesehen werden, was zu tun
ist, um LMv7 zu installieren, mehr nicht!

Das Script könnte als "Repeatable Install" für verlässliche Testläufe dienen.

Im LM-Forum gibts eine
[Diskussion](https://ask.linuxmuster.net/t/lm-v7-walkthrough/4552/92)

