<TeXmacs|2.1.4>

<style|<tuple|generic|alt-text>>

<\body>
  <doc-data|<doc-title|Tabellen und barrierefreie
  Abbildungen>|<doc-author|<author-data|<author-name|TeXmacs Accessibility
  Team>>>>

  <section|Barrierefreie Tabellen>

  Tabelle <reference|tab:standards> zeigt eine \<#00DC\>bersicht relevanter
  PDF-Standards mit Spaltenausrichtung und verbundenen Zellen.

  <big-table|<tabular|<tformat|<cwith|1|1|1|-1|cell-bborder|1ln>|<cwith|1|-1|1|1|cell-halign|l>|<cwith|1|-1|2|2|cell-halign|c>|<cwith|1|-1|3|3|cell-halign|r>|<cwith|4|4|1|2|cell-col-span|2>|<table|<row|<cell|<strong|Standard>>|<cell|<strong|Fokus>>|<cell|<strong|Jahr>>>|<row|<cell|PDF/A-2b>|<cell|Langzeitarchivierung>|<cell|2011>>|<row|<cell|PDF/UA-1>|<cell|Barrierefreiheit>|<cell|2012>>|<row|<cell|Gesamtanzahl
  gepr\<#00FC\>fter Standards>|<cell|>|<cell|2>>>>>|Vergleich wichtiger
  PDF-Standards<label|tab:standards>>

  <subsection|Gerahmte Block-Tabelle>

  <block|<tformat|<table|<row|<cell|<strong|Tag>>|<cell|<strong|Typst-Ziel>>>|<row|<cell|<verbatim|alt-image>>|<cell|<verbatim|#image(...,
  alt: ...)>>>|<row|<cell|<verbatim|decorative-image>>|<cell|<verbatim|#pdf.artifact(image(...))>>>>>>

  <section|Abbildungen mit Alt-Texten>

  Abbildung <reference|fig:arch> zeigt die Export-Pipeline von GNU TeXmacs
  \<#00FC\>ber Typst nach PDF/UA.

  <big-figure|<alt-image|../fixtures/diagram.svg|Flussdiagramm der
  Export-Pipeline: GNU TeXmacs zu Typst zu PDF/UA>|Architektur der
  barrierefreien Export-Pipeline<label|fig:arch>>

  Nachfolgend ein rein dekoratives Trennelement, das als PDF/UA-Artefakt
  markiert wird:

  <decorative-image|../fixtures/diagram.svg>

  Und ein regul\<#00E4\>res TeXmacs-Bild mit eigener Breite, das vom
  Extras-Makro mit <verbatim|alt-image-wrap> umh\<#00FC\>llt wurde:

  <alt-image-wrap|<image|../fixtures/diagram.svg|0.5par|||>|Kompakte
  Darstellung der TeXmacs-Typst-PDF/UA-Pipeline>
</body>

<\initial>
  <\collection>
    <associate|font|roman>
    <associate|language|german>
    <associate|page-medium|paper>
  </collection>
</initial>
