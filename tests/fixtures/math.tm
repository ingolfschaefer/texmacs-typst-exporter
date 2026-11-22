<TeXmacs|2.1.4>

<style|<tuple|generic|alt-text>>

<\body>
  <doc-data|<doc-title|Mathematik-Export nach Typst>|<doc-author|<author-data|<author-name|TeXmacs
  Tester>>>>

  <section|Inline- und Display-Mathematik>

  F\<#00FC\>r alle <math|x\<in\>\<bbb-R\>> mit <math|\<alpha\>\<leq\>x\<leq\>\<beta\>>
  gilt die Quadratwurzel <math|<sqrt|x<rsup|2>+1>> sowie die dritte Wurzel
  <math|<sqrt|x|3>> und der Bruch <math|<frac|\<alpha\>+\<beta\>|2>>.

  Die Eulersche Identit\<#00E4\>t lautet (siehe Gleichung
  <reference|eq:euler>):

  <\equation>
    e<rsup|i*\<pi\>>+1=0<label|eq:euler>
  </equation>

  <subsection|Summen, Integrale und Vektoren>

  <\equation*>
    <big|sum><rsub|k=1><rsup|\<infty\>><frac|1|k<rsup|2>>=<frac|\<pi\><rsup|2>|6>,<space|1em><big|int><rsub|0><rsup|\<infty\>>e<rsup|-x<rsup|2>>*<math-up|d>x=<frac|<sqrt|\<pi\>>|2>
  </equation*>

  Mit Vektoren und Akzenten: <math|<wide|v|\<vect\>>=<around|(|v<rsub|1>,v<rsub|2>|)>>,
  <math|<wide|x|^>>, <math|<wide|z|\<bar\>>>.

  <subsection|Matrizen, Fallunterscheidungen und Gleichungssysteme>

  <\equation*>
    A=<matrix|<tformat|<table|<row|<cell|1>|<cell|2>>|<row|<cell|3>|<cell|4>>>>>,<space|1em><det|<tformat|<table|<row|<cell|a>|<cell|b>>|<row|<cell|c>|<cell|d>>>>>=a*d-b*c
  </equation*>

  <\equation*>
    <around|\||x|\|>=<choice|<tformat|<table|<row|<cell|x>|<cell|<text|falls
    >x\<geq\>0>>|<row|<cell|-x>|<cell|<text|falls >x\<less\>0>>>>>
  </equation*>

  <\eqnarray*>
    <tformat|<table|<row|<cell|<around|(|a+b|)><rsup|2>>|<cell|=>|<cell|a<rsup|2>+2*a*b+b<rsup|2>>>|<row|<cell|<around|(|a-b|)><rsup|2>>|<cell|=>|<cell|a<rsup|2>-2*a*b+b<rsup|2>>>>>
  </eqnarray*>
</body>

<\initial>
  <\collection>
    <associate|font|roman>
    <associate|language|german>
    <associate|page-medium|paper>
  </collection>
</initial>
