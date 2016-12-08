(* ::Package:: *)

(* Mathematica Source File  *)
(* Created by Mathematica Plugin for IntelliJ IDEA *)
(* :Author: szhorvat *)
(* :Date: 2016-12-02 *)


$appName = "IGraphM";
$LTemplateRepo = "~/Repos/LTemplate";


printAbort[str_] := (Print["ABORTING: ", Style[str, Red, Bold]]; Quit[])
If[$VersionNumber < 10.0, printAbort["Mathematica 10.0 or later required."]]


$dir =
    Which[
      $InputFileName =!= "", DirectoryName[$InputFileName],
      $Notebooks, NotebookDirectory[],
      True, printAbort["Cannot determine script directory."]
    ]


rg = RunProcess[{"git", "--version"}];
If[rg === $Failed || rg["ExitCode"] != 0,
  printAbort["git is not available."]
]


SetDirectory[$dir]


$buildDir = FileNameJoin[{$dir, "release"}]


If[DirectoryQ[$buildDir],
  Print["Deleting release directory."]
  DeleteDirectory[$buildDir, DeleteContents->True]
]


$appSource = FileNameJoin[{$dir, $appName}]
$appTarget = FileNameJoin[{$buildDir, $appName}]


CreateDirectory[$appTarget, CreateIntermediateDirectories->True]


Print["git-archive IGraphM"]


$gitArch = FileNameJoin[{$buildDir, $appName<>".tar"}]


RunProcess[{"git", "archive", "--format", "tar", "-o", $gitArch, "HEAD:IGraphM"}]


ExtractArchive[$gitArch, $appTarget]
DeleteFile[$gitArch]


SetDirectory[$appTarget]


source = Import["IGraphM.m", "String"];


repl = {
  "Get[\"LTemplate`LTemplatePrivate`\"]" -> "Get[\"IGraphM`LTemplate`LTemplatePrivate`\"]",
  "\"LazyLoading\" -> False" -> "\"LazyLoading\" -> True"
};


source = StringReplace[source, repl, Length[repl]];


template = StringTemplate[source, Delimiters -> {"%%", "%%", "<%", "%>"}];


Print["Loading IGraphM paclet."]
PacletDirectoryAdd[$dir]
Needs[$appName <> "`"]


versionData = <|
  "version" -> Lookup[PacletInformation[$appName], "Version"],
  "mathversion" -> Lookup[PacletInformation[$appName], "WolframVersion"],
  "date" -> DateString[{"MonthName", " ", "Day", ", ", "Year"}]
|>


source = template[versionData];


Export[FileNameJoin[{$appTarget, "IGraphM.m"}], source, "String"]


DeleteFile["BuildSettings.m"]


(***** Copy LTemplate *****)

Print["git-archive LTemplate"]

SetDirectory@CreateDirectory["LTemplate"]

RunProcess[{"git", "archive", "--format", "tar", "-o", "LTemplate.tar", "HEAD:LTemplate", "--remote=" <> $LTemplateRepo}]

ExtractArchive["LTemplate.tar"]

DeleteDirectory["Documentation", DeleteContents -> True]
DeleteFile[{"IncludeFiles/Doxyfile", "LTemplate.tar"}]

ResetDirectory[] (* LTemplate *)


(***** Clean up documentation *****)

Print["\nProcessing documentation."]
SetDirectory@FileNameJoin[{"Documentation", "English"}]
AddPath["PackageTools"]
Needs["PackageTools`"]

Print["Evaluating..."]
With[{$buildDir = $buildDir},
  MRun[
    MCode[
      PacletDirectoryAdd[$buildDir];
      SetOptions[First[$Output], FormatType -> StandardForm];
      RewriteNotebook[
        NBFEProcess[NotebookEvaluate[#, InsertResults -> True]&]
      ]["IGDocumentation.nb"]
    ],
    "10.3"
  ]
]

Print["Rewriting..."]
MRun[
  MCode[
    RewriteNotebook[
      NBSetOptions[Saveable -> False] /*
      NBRemoveChangeTimes /*
      NBResetWindow /*
      NBDisableSpellCheck /*
      NBRemoveOptions[{PrivateNotebookOptions, Visible}] /*
      NBSetOptions[StyleDefinitions -> NBImport["Stylesheet.nb"]]
    ]["IGDocumentation.nb"];
  ],
  "10.0"
]
DeleteFile["Stylesheet.nb"]
ResetDirectory[] (* Documentation *)


ResetDirectory[] (* $appTarget *)

Print["\nPacking paclet..."]
PackPaclet[$appTarget]


Print["\nFinished.\n"]


ResetDirectory[] (* $dir *)