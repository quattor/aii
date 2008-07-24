% datagrid.cls: 
%
% $Id: datagrid.cls,v 1.2 2003/07/25 11:49:14 eferro Exp $
%
% $Author: eferro $
%
% $Log: datagrid.cls,v $
% Revision 1.2  2003/07/25 11:49:14  eferro
% Release 1.1.0
%
% Revision 1.13  2003/03/28 10:21:18  szamcsi
% A few modifications:
%
%   o geometry parameters back to the previos setting
%     v3 processes the parameters differently than v2.
%     If you want to use it with geometry.sty v3, then
%     switch to compatibility mode (compat2). See README
%
%   o removing the lightgray boxes around the page numbers
%     (the Word style doesn't have it either)
%
%   o <email@address> format both in PDF and PostScript outputs
%
% Revision 1.12  2003/02/20 16:01:25  szamcsi
% Solving the PDFDocEncoded vs. \uppercase problem:
% the whole TOC line was passed to the hyperref/PDF
% module to generate bookmarks in the PDF document.
% The hyperref module didn't recognise the \uppercase
% macro (pdfenc1), so we have to generate two types
% of TOC lines using the \texorpdfstring macro.
%
% Revision 1.11  2002/10/08 07:27:23  diana
% removed foot in geometry and changed footskip to produce a visible footer in ps file
%
% Revision 1.10  2002/09/13 17:44:10  szamcsi
% \HTTP born again :-)
%
% Revision 1.9  2002/09/12 07:38:21  szamcsi
% stepping back
%
% Revision 1.8  2002/09/11 17:05:12  szamcsi
% copied \Image from datagrid.sty
%
% Revision 1.7  2002/09/02 20:01:36  diana
% Now table of contents prints in uppercase and with dots between the title
% and the page number.
%
% Revision 1.6  2002/08/28 21:37:12  diana
% Added CVS tags to file header.
%
%
%v1.1 2002-08-23 by Diana Bosio
%v1.0 2002-06-20 by Paul Millar
% based on original Style sheet by Frohner ?kos <Akos.Frohner@cern.ch>
% Thanks are due to Norman Gray 
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{datagrid}[2002/06/20 European DataGrid LaTeX Class]
\typeout{EDG LaTeX class -- 2002/06/13  Rock Lobster!}

%% Notes: This class file tries, as largely as possible, to copy the Microsoft
%% Word template document EDMS 2098656 v2.2.  Differences and notes are listed
%% below:
%%   o  The Word Template uses 11pt for the main body, but 12 point
%%      occasionally. Any such occurrence of 12pt is mapped into 11pt in this
%%      class-file.
%%   o  This class inherits 11pt article. In that class Huge=30pt and
%%      LARGE=22pt, which matches the required point-size for the title page.
%%   o  The parskip in the Word doc is exactly 1.4mm (0.7mm above and below).
%%      Here we've taken the liberty of adding some glue to make things fit
%%      better.
%%   o  The Word Template shows all the (sub)sections on the contents page in 
%%      capitals and subsubsections in italics. The LateX class doesn't.

%% Interface - example of an option, should we want to use these later.
%\newif\ifmonotitle\monotitlefalse

%\DeclareOption{mono}{\monotitletrue}

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions


% Inherit!
\LoadClass[11pt]{article}

% Necessary packages:
\RequirePackage{lastpage}
\RequirePackage{tabularx}
\RequirePackage{pslatex}
\RequirePackage{times}
\RequirePackage{verbatim}
\RequirePackage{geometry}
\RequirePackage{url}

\usepackage[hang,bf,small]{caption}

%
% We now define a new \if command to test for PDF being enabled.
% It is important because loading graphicx overrides the definition
% of \pdfoutput and sets it to true even when PDF is not enabled.
% Use \ifpdf instead of \ifx\pdfoutput\undefined hereafter.
%

\newif\ifpdf
\ifx\pdfoutput\undefined
        \pdffalse
        % \typeout{PDF _not_ defined}
\else
        \pdfoutput=1
        \pdftrue
        % \typeout{PDF _is_ defined}
\fi

\ifpdf
        \usepackage[pdftex,
                pdfpagemode={UseOutlines},bookmarks=true,bookmarksopen=true,
                bookmarksopenlevel=0,bookmarksnumbered=true,
                hypertexnames=false,colorlinks,linkcolor={blue},
                citecolor={blue},urlcolor={red},
                pdfstartview={FitV}]{hyperref}
\else
        \usepackage{hyperref}
\fi
    
\ifpdf
        \usepackage[pdftex]{graphicx}
        \pdfcompresslevel 9
        \pdfadjustspacing 1
\else
        \usepackage[dvips]{graphicx}
\fi

\usepackage{color}

\def\footsize{5mm}

%%
%% PAGE GEOMETRY DEFINITIONS
%%
% From Template file
\geometry{a4paper,top=12.5mm,headheight=12.5mm,headsep=5mm,foot=\footsize,footskip=13.3mm,bottom=12.5mm}
\geometry{right=25mm,left=25mm}


% APM -- I don't think these are right, my impression is above is correct
%\geometry{a4paper,margin=0.98in,headheight=0.72in}


%%
%% PAGE COLOUR DEFINITIONS
%%
\definecolor{blue}{rgb}{0.1,0.1,0.5}
\definecolor{lightgrey}{gray}{0.65}


% paulm's prefered name ...
\def\bibname{References}

\setlength{\parindent}{0pt}
\setlength{\parskip}{1.4mm plus 0.4mm minus 0.2mm}

\def\@defaultfooter{
  \def\@oddfoot{\vbox to \footsize {%
    {\color{blue}\hrule width \textwidth height 1pt depth 0pt}%
    \vfil
    \small\hbox to \textwidth{\ISTNumber%
                \hfil
                \hbox{\colorbox{yellow}{\MakeUppercase{\@Dissemination}}}%
                \hfil
                \hbox{\thepage/\pageref{LastPage}}}%
    }%
  }%
}


\def\ps@title{%
  \@defaultfooter
  \def\@oddhead{\hbox to \textwidth{\LargeDataGridLogo\hfil\ISTLogo}}
}

\def\ps@headings{%
  \@defaultfooter
  \def\@oddhead{\vbox to \headheight{%
%\hrule width \textwidth height 1pt\relax
      \vbox to 0.75\headheight{%
        \hbox to \textwidth{%
          \hbox to 0pt{\DataGridLogo\hss}%
          \hfil
         \hbox to 8cm{%
           \vbox to 0.75\headheight{%
             \vfil
             \parbox{8cm}{%
               \centering\color{blue}%
                \textbf{\MakeUppercase{\@title}}%
\ifx\@Subtitle\@empty\else
              \par\textbf{\scriptsize\@Subtitle}%
\fi
             }%
             \vfil
           }%
         }%
         \hfil
%\hbox to 0pt{\vrule width 1pt height 10pt depth 0pt \hss}%
%%           {\scriptsize\setlength{\parskip}{0pt}\setlength{\topsep}{0pt}%
%% %              \vbox to 0.75\headheight{%
%%                   \parbox{4cm}{x%
%%                       \begin{flushright}%
%%                           \textit{Doc. Identifier}:\\
%%                        \textbf{\@DocIdentifier}\\
%%                           \vfil
%%                           \textit{Date}: \textbf{\@date}
%%                       \end{flushright}%
%%                   }%
%% %              }%
%%           }%
\hbox to 0pt{\hss\vbox to 0.75\headheight{%\hrule
\tiny%\scriptsize
\parfillskip0pt
\leftskip 0pt plus 1fil
\parskip0ex
\textit{Doc.\ Identifier}:
\par
\textbf{\@DocIdentifier}
\vfil
\textit{Date}: \textbf{\@date}
%\hrule
}}%
%          \hbox to 4cm{\scriptsize
%            \vbox to 0.75\headheight{%
%              \parbox{4cm}{
%              \halign{\hfill####\cr
%                \textit{Doc. Identifier}:\cr
%               \textbf{\@DocIdentifier}\cr
%             % \noalign{\vfil}
%                \textit{Date}: \textbf{\@date}\cr
%              }}%
%              \vfil
%            }%
%         }%
        }%
      }%
%\hrule width \textwidth height 1pt\relax
      \vfil\vskip 2.5mm\relax
      {\color{blue}\hrule width \textwidth height 1pt depth 0pt}%
    }%
  }%
}

\pagestyle{headings}

\setlength{\captionmargin}{1cm}


% image file extensions respective to the output format
\ifpdf
        \DeclareGraphicsExtensions{.jpg,.pdf,.png}
        \pdfcompresslevel=9
        \pdfinfo{ /Title (\jobname) }
\else   
        \DeclareGraphicsExtensions{.eps}
\fi

\def\frontboxwidth{9.1cm}%



%%
%% Define our title page
%%
\AtBeginDocument{
\pagestyle{title}%
\hbox{}% Force top of page
\vfill
{\centering
        \Huge\bf\textsf{\textcolor{blue}{DataGRID}}\\[15mm]%
        \LARGE\sc\textsf{\@title}\\[5mm]%
        \ifx\@Subtitle\@empty\else
            \normalsize\textsf{\@Subtitle}\\[5mm]%
        \fi
}%
\vfill
\hbox to \textwidth{%
      \hfil
      \vbox{
      {\color{blue}\hrule width \frontboxwidth height 1mm depth 0pt}%
      \hbox to \frontboxwidth{\sf
          \begin{tabularx}{\frontboxwidth}{l>{\raggedright\arraybackslash}X}%
                Document identifier: & \textbf{\@DocIdentifier}\\[3mm]%
                EDMS id: & \textbf{\@EDMSid}\\[3mm]%
                Date: & \textbf{\sf\@date}\\[3mm]%
                Work package:& \textbf{\@WorkPackage}\\[3mm]
                Partner(s): & \textbf{\@Partner}\\[3mm]
                Lead Partner: & \textbf{\@LeadPartner}\\[3mm]
                Document status: & \textbf{\@DocStatus}\\[3mm]
                Author(s): & {\@author}\\[3mm]
                File:& \textbf{\jobname}\\[3mm]
          \end{tabularx}%
     }%
      {\color{blue}\hrule width \frontboxwidth height 1mm depth 0pt}%
     }%
}%
\vfill
{\sf\underline{Abstract}: \@Abstract}
\vfill
\newpage  % end of the first page
\pagestyle{headings}
\setcounter{tocdepth}{3}
\tableofcontents
\newpage
} % End of AtBeginningDocument


%
% EDG style small-capital section titles.
%
% The numbering is aligned with the WinWord style, 
% although it is not common in the english typography...
%
\newcommand{\sectionbreak}{\newpage}
\renewcommand{\thesection}{\arabic{section}.}
\renewcommand{\thesubsection}{\thesection\arabic{subsection}.}
\renewcommand{\thesubsubsection}{\thesubsection\arabic{subsubsection}.}

\renewcommand\section{\@startsection {section}{1}{\z@}%
                                   {-3.5ex \@plus -1ex \@minus -.2ex}%
                                   {2.3ex \@plus.2ex}%
                                   {\normalfont\Large\bfseries\sffamily\scshape}}

\renewcommand\subsection{\@startsection{subsection}{2}{\z@}%
                                     {-3.25ex\@plus -1ex \@minus -.2ex}%
                                     {1.5ex \@plus .2ex}%
                                     {\normalfont\large\bfseries\sffamily\scshape}}
\renewcommand\subsubsection{\@startsection{subsubsection}{3}{\z@}%
                                     {-3.25ex\@plus -1ex \@minus -.2ex}%
                                     {1.5ex \@plus .2ex}%
                                     {\normalfont\normalsize\bfseries\sffamily\scshape}}



%% APM NEED TO REDEFINE section
%\titleformat{\section}{\Large\bfseries\sffamily\scshape}{\thesection}{1em}{}
%\titlecontents{section} [2em] {\vspace*{4pt}}
%       {\large \sc \bfseries \contentslabel{2em}}
%       {\large \sc \bfseries \hspace*{-2em}}
%       {\large \textbf{\titlerule*[1ex]{.}\contentspage}} [\vspace*{4pt}]

%\titleformat{\subsection}{\large\bfseries\sffamily\scshape}{\thesubsection}{1em}{}
%\titlecontents{subsection} [5em] {}
%       {\sc \contentslabel{3em}}
%       {\sc \hspace*{-3em}}
%       {\titlerule*[1ex]{.}\contentspage} 


%
% common constants
%
\def\ISTNumber{IST-2000-25182}
\def\DataGridLogo{\includegraphics[height=0.75\headheight]{datagrid}}
\def\LargeDataGridLogo{\includegraphics[height=\headheight]{datagrid}}
\def\ISTLogo{\includegraphics[height=\headheight]{ist}}

%
% parameters to be supplied by the author
%
\def\Subtitle#1{\gdef\@Subtitle{#1}}
\gdef\@Subtitle{\@latex@warning@no@line{No \noexpand\Subtitle given}}

\def\DocIdentifier#1{\gdef\@DocIdentifier{#1}}
\gdef\@DocIdentifier{\@latex@warning@no@line{No \noexpand\DocIdentifier given %
        (e.g. DataGrid-01-TEN-0109-1-0)}}

\def\EDMSid#1{\gdef\@EDMSid{#1}}
\gdef\@EDMSid{\@latex@warning@no@line{No \noexpand\EDMSid given %
        (e.g. 3738)}}

\def\WorkPackage#1{\gdef\@WorkPackage{#1}}
\gdef\@WorkPackage{\@latex@warning@no@line{No \noexpand\WorkPackage given %
        (e.g. WP2 Data Management)}}

\def\Partner#1{\gdef\@Partner{#1}}
\gdef\@Partner{\@latex@warning@no@line{No \noexpand\Partner given %
        (e.g. CERN, INFN)}}

\def\LeadPartner#1{\gdef\@LeadPartner{#1}}
\gdef\@LeadPartner{\@latex@warning@no@line{No \noexpand\LeadPartner given %
        (e.g. CERN)}}

\def\DocStatus#1{\gdef\@DocStatus{#1}}
\gdef\@DocStatus{\@latex@warning@no@line{No \noexpand\DocStatus given %
        (e.g. DRAFT, WORKING, DELIVERED)}}

\def\Dissemination#1{\gdef\@Dissemination{#1}}
\gdef\@Dissemination{\@latex@warning@no@line{No \noexpand\Dissemination given %
        (e.g. PUBLIC, INTERNAL, ...)}}

\long\def\Abstract#1{\gdef\@Abstract{#1}}
\gdef\@Abstract{\@latex@warning@no@line{No \noexpand\Abstract given}}

%%
%% Define the abstract using an environment abstract

%
% This will produce the mailto link in the PDF file
%
%
% We use the URL package, which does this nicely. The old way (\HTTP) was
% a bit buggy as it had problems with '~'s and '_'s
%
\urlstyle{sf}
\ifpdf
  \newcommand{\Email}[1]{\href{mailto:#1}{<{#1}>}}
  \newcommand{\HTTP}[1]{\href{#1}{\url{#1}}}
\else
  \newcommand{\Email}[1]{\textsf{<{#1}>}}
  \newcommand{\HTTP}[1]{\url{#1}}
\fi


%
% We now redifine \part and \section so that the table of contents
% has the sections/parts in upper case.
%
% Note: need to use \uppercase because \MakeUppercase is not robust
%
\def\@part[#1]#2{%
    \ifnum \c@secnumdepth >\m@ne
      \refstepcounter{part}%
      \addcontentsline{toc}{part}{\thepart\hspace{1em}\uppercase{#1}}%
    \else
      \addcontentsline{toc}{part}{\uppercase{#1}}%
    \fi
    {\parindent \z@ \raggedright
     \interlinepenalty \@M
     \normalfont
     \ifnum \c@secnumdepth >\m@ne
       \Large\bfseries \partname\nobreakspace\thepart
       \par\nobreak
     \fi
     \huge \bfseries #2%
     \markboth{}{}\par}%
    \nobreak
    \vskip 3ex
    \@afterheading}

\def\@sect#1#2#3#4#5#6[#7]#8{%
  \ifnum #2>\c@secnumdepth
    \let\@svsec\@empty
  \else
    \refstepcounter{#1}%
    \protected@edef\@svsec{\@seccntformat{#1}\relax}%
  \fi
  \@tempskipa #5\relax
  \ifdim \@tempskipa>\z@
    \begingroup
      #6{%
        \@hangfrom{\hskip #3\relax\@svsec}%
          \interlinepenalty \@M #8\@@par}%
    \endgroup
    \csname #1mark\endcsname{\uppercase{#7}}%
    \addcontentsline{toc}{#1}{%
      \ifnum #2>\c@secnumdepth \else
        \protect\numberline{\csname the#1\endcsname}%
      \fi
      \texorpdfstring{\uppercase{#7}}{#7}}%
  \else
    \def\@svsechd{%
      #6{\hskip #3\relax
      \@svsec #8}%
      \csname #1mark\endcsname{\uppercase{#7}}%
      \addcontentsline{toc}{#1}{%
        \ifnum #2>\c@secnumdepth \else
          \protect\numberline{\csname the#1\endcsname}%
        \fi
        \texorpdfstring{\uppercase{#7}}{#7}}}%
  \fi
  \@xsect{#5}}

% \addcontentsline{toc} expands to \contentsline{NAME}
% which in turn expands to \l@NAME.  So, to specify
% the table of contents, we must define \l@chapter, \l@section,
% \l@subsection, ... ; to specify the list of figures, we must define
% \l@figure; and so on.  Most of these can be defined with the
% \@dottedtocline command, which produces a contents line with dots
% between the title and the page number. It works as follows:
%
% \@dottedtocline{LEVEL}{INDENT}{NUMWIDTH}
%    LEVEL    : An entry is produced only if LEVEL < or = value of
%               'tocdepth' counter.  Note, \chapter is level 0, \section
%               is level 1, etc.
%    INDENT   : The indentation from the outer left margin of the start of
%               the contents line.
%    NUMWIDTH : The width of a box in which the section number is to go,
%               if TITLE includes a \numberline command.
%

\def\l@part{\@dottedtocline{1}{4em}{2.0em}}
\def\l@subsection{\@dottedtocline{2}{1.5em}{2.3em}}
\def\l@subsubsection{\@dottedtocline{3}{3.8em}{3.2em}}
\def\l@paragraph{\@dottedtocline{4}{7.0em}{4.1em}}
\def\l@subparagraph{\@dottedtocline{5}{10em}{5em}}

