Option Explicit

Const swDocPART = 1
Const swSolidBody = 0

Dim swApp
Dim model
Dim part
Dim bodies
Dim bodyCount
Dim faceCount
Dim body
Dim partBox
Dim massProp

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
  WScript.Echo "TITLE=" & model.GetTitle()
  WScript.Echo "DOCTYPE=" & CStr(model.GetType())
  WScript.Quit 3
End If

Set part = model
bodies = part.GetBodies2(swSolidBody, True)
bodyCount = CountVariantArray(bodies)
faceCount = 0

If IsArray(bodies) Then
  For Each body In bodies
    faceCount = faceCount + CLng(body.GetFaceCount())
  Next
End If

partBox = part.GetPartBox(True)
Set massProp = model.Extension.CreateMassProperty()

WScript.Echo "TITLE=" & SafeText(model.GetTitle())
WScript.Echo "PATH=" & SafeText(model.GetPathName())
WScript.Echo "BODY_COUNT=" & CStr(bodyCount)
WScript.Echo "FACE_COUNT=" & CStr(faceCount)

If IsArray(partBox) Then
  On Error Resume Next
  WScript.Echo "BOX_MIN_M=" & FormatNumberDot(partBox(0)) & "," & FormatNumberDot(partBox(1)) & "," & FormatNumberDot(partBox(2))
  WScript.Echo "BOX_MAX_M=" & FormatNumberDot(partBox(3)) & "," & FormatNumberDot(partBox(4)) & "," & FormatNumberDot(partBox(5))
  WScript.Echo "BOX_SIZE_M=" & _
    FormatNumberDot(partBox(3) - partBox(0)) & "," & _
    FormatNumberDot(partBox(4) - partBox(1)) & "," & _
    FormatNumberDot(partBox(5) - partBox(2))
  WScript.Echo "BOX_SIZE_MM=" & _
    FormatNumberDot((partBox(3) - partBox(0)) * 1000) & "," & _
    FormatNumberDot((partBox(4) - partBox(1)) * 1000) & "," & _
    FormatNumberDot((partBox(5) - partBox(2)) * 1000)
  If Err.Number <> 0 Then
    WScript.Echo "BOX_ERROR=" & SafeText(Err.Description)
    Err.Clear
  End If
  On Error GoTo 0
End If

If Not massProp Is Nothing Then
  On Error Resume Next
  WScript.Echo "VOLUME_M3=" & FormatNumberDot(massProp.Volume)
  WScript.Echo "VOLUME_MM3=" & FormatNumberDot(CDbl(massProp.Volume) * CDbl(1000000000))
  WScript.Echo "SURFACE_AREA_M2=" & FormatNumberDot(massProp.SurfaceArea)
  WScript.Echo "SURFACE_AREA_MM2=" & FormatNumberDot(CDbl(massProp.SurfaceArea) * CDbl(1000000))
  WScript.Echo "MASS_KG=" & FormatNumberDot(massProp.Mass)
  WScript.Echo "DENSITY_KG_M3=" & FormatNumberDot(massProp.Density)
  If Err.Number <> 0 Then
    WScript.Echo "MASSPROP_ERROR=" & SafeText(Err.Description)
    Err.Clear
  End If
  On Error GoTo 0
End If

Function CountVariantArray(value)
  If IsEmpty(value) Then
    CountVariantArray = 0
  ElseIf IsArray(value) Then
    CountVariantArray = UBound(value) - LBound(value) + 1
  Else
    CountVariantArray = 0
  End If
End Function

Function FormatNumberDot(value)
  Dim s
  s = CStr(CDbl(value))
  s = Replace(s, ",", ".")
  FormatNumberDot = s
End Function

Function SafeText(value)
  If IsNull(value) Then
    SafeText = ""
  Else
    SafeText = CStr(value)
  End If
End Function
