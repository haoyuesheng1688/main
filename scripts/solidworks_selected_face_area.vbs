Option Explicit

Const swDocPART = 1
Const swSelFACES = 2

Dim swApp
Dim model
Dim selMgr
Dim selCount
Dim selType
Dim face
Dim areaM2

On Error Resume Next
Set swApp = GetObject(, "SldWorks.Application")
If Err.Number <> 0 Then
  WScript.Echo "ERROR: Could not connect to the running SolidWorks instance."
  WScript.Quit 1
End If
On Error GoTo 0

Set model = swApp.ActiveDoc
If model Is Nothing Then
  WScript.Echo "ERROR: SolidWorks has no active document."
  WScript.Quit 2
End If

If model.GetType() <> swDocPART Then
  WScript.Echo "ERROR: Active document is not a Part document."
  WScript.Quit 3
End If

Set selMgr = model.SelectionManager
selCount = selMgr.GetSelectedObjectCount2(-1)
WScript.Echo "SELECTED_COUNT=" & CStr(selCount)

If selCount < 1 Then
  WScript.Echo "ERROR: No selection found. Please select one inlet face in SolidWorks."
  WScript.Quit 4
End If

selType = selMgr.GetSelectedObjectType3(1, -1)
WScript.Echo "SELECTED_TYPE=" & CStr(selType)

If selType <> swSelFACES Then
  WScript.Echo "ERROR: First selected object is not a face."
  WScript.Quit 5
End If

Set face = selMgr.GetSelectedObject6(1, -1)
If face Is Nothing Then
  WScript.Echo "ERROR: Could not resolve selected face."
  WScript.Quit 6
End If

areaM2 = CDbl(face.GetArea())

WScript.Echo "TITLE=" & CStr(model.GetTitle())
WScript.Echo "FACE_AREA_M2=" & FormatNumberDot(areaM2)
WScript.Echo "FACE_AREA_MM2=" & FormatNumberDot(CDbl(areaM2) * CDbl(1000000))

Function FormatNumberDot(value)
  Dim s
  s = CStr(CDbl(value))
  s = Replace(s, ",", ".")
  FormatNumberDot = s
End Function
