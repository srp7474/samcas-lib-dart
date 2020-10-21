%echo off
echo uses dartdoc to generate the documentaion package
set flutter_root=D:\pgms\flutter-1-20\flutter
call %flutter_root%\bin\cache\dart-sdk\bin\dartdoc --inject-html

echo ***** copying files *********
xcopy doc\api H:\data\gael-home\war\docs\samcas\api /SY
