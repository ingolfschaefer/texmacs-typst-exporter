<TeXmacs|2.1.4>

<style|<tuple|generic|alt-text>>

<\body>
  <doc-data|<doc-title|Barrierefreie Dokumente mit
  TeXmacs>|<doc-subtitle|Konvertierung nach Typst und
  PDF/UA>|<doc-author|<author-data|<author-name|Max
  Mustermann>>>|<doc-author|<author-data|<author-name|Erika
  Musterfrau>>>|<doc-date|22. November 2026>>

  <\abstract-data>
    <\abstract>
      Dieses Testdokument pr\<#00FC\>ft Metadaten, Schriften, Listen, Zitate,
      Code-Bl\<#00F6\>cke, Fu\<#00DF\>noten und Querverweise.
    </abstract>
  </abstract-data>

  <section|Listen und Struktur<label|sec:listen>>

  Wie in Abschnitt <reference|sec:listen> gezeigt, unterst\<#00FC\>tzt der
  Exporter verschiedene Listenarten<footnote|Fu\<#00DF\>noten werden
  barrierefrei exportiert.>:

  <\itemize>
    <item>Erster Punkt mit <strong|Fettdruck> und <em|Kursivschrift>.

    <item>Zweiter Punkt mit <verbatim|inline_code()> und
    <with|color|blue|blauer Farbe>.

    <\enumerate>
      <item>Verschachtelter Punkt eins.

      <item>Verschachtelter Punkt zwei.
    </enumerate>
  </itemize>

  <\description>
    <item*|PDF/A>Archivierungsstandard f\<#00FC\>r langfristige Lesbarkeit.

    <item*|PDF/UA>Standard f\<#00FC\>r universelle Barrierefreiheit
    (Universal Accessibility).
  </description>

  <subsection|Zitate, Code und Theoreme>

  <\quotation>
    Barrierefreiheit ist kein Zusatzfeature, sondern ein Grundpfeiler guter
    Dokumentgestaltung.
  </quotation>

  <\python-code>
    def greet(name: str) -\> str:
        return f"Hallo {name}!"
  </python-code>

  <\definition>
    Ein Dokument hei\<#00DF\>t <dfn|semantisch strukturiert>, wenn alle
    \<#00DC\>berschriften, Listen und Tabellen echte Struktur-Tags tragen.
  </definition>
</body>

<\initial>
  <\collection>
    <associate|font|roman>
    <associate|font-base-size|11>
    <associate|language|german>
    <associate|page-medium|paper>
    <associate|page-type|a4>
  </collection>
</initial>
