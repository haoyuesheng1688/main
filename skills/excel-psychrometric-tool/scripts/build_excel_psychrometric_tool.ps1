param(
    [string]$OutputPath = (Join-Path (Get-Location) 'psychrometric_air_tool.xlsm')
)

$ErrorActionPreference = 'Stop'

try {
    $excel = [Runtime.InteropServices.Marshal]::GetActiveObject('Excel.Application')
} catch {
    $excel = New-Object -ComObject Excel.Application
}

$excel.Visible = $true
$excel.DisplayAlerts = $false

$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)

foreach ($book in @($excel.Workbooks)) {
    if ($book.FullName -eq $outputFullPath) {
        $book.Close($false)
        break
    }
}

if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Force
}

$wb = $excel.Workbooks.Add()
$ws = $wb.Worksheets.Item(1)
$ws.Name = 'PsychroTool'

$ws.Range('A1').Value2 = 'Moist Air Parameter Calculator'
$ws.Range('A2').Value2 = 'Enter any two independent values in B4:B7, then click Calculate. Red = input, green = output.'
$ws.Range('A3').Value2 = 'Parameter'
$ws.Range('B3').Value2 = 'Value'
$ws.Range('C3').Value2 = 'Role'
$ws.Range('D3').Value2 = 'Unit / note'

$ws.Range('A4').Value2 = 'Air temperature'
$ws.Range('A5').Value2 = 'Relative humidity'
$ws.Range('A6').Value2 = 'Humidity ratio'
$ws.Range('A7').Value2 = 'Dew point temperature'
$ws.Range('D4').Value2 = 'deg C'
$ws.Range('D5').Value2 = '%'
$ws.Range('D6').Value2 = 'g/kg dry air'
$ws.Range('D7').Value2 = 'deg C'

$ws.Range('A9').Value2 = 'Assumption'
$ws.Range('B9').Value2 = 'Standard atmospheric pressure: 101.325 kPa. Saturation vapor pressure uses a Magnus approximation.'
$ws.Range('A10').Value2 = 'Note'
$ws.Range('B10').Value2 = 'Humidity ratio + dew point alone are both vapor-pressure information, so they cannot uniquely determine air temperature and relative humidity.'

$ws.Range('A12').Value2 = 'How to use'
$ws.Range('B12').Value2 = 'Any changed input cell is marked red. Calculated cells are marked green.'

$ws.Range('A1:D1').Merge()
$ws.Range('A1').Font.Bold = $true
$ws.Range('A1').Font.Size = 16
$ws.Range('A3:D3').Font.Bold = $true
$ws.Range('A3:D7').Borders.LineStyle = 1
$ws.Range('A9:B10').Borders.LineStyle = 1
$ws.Range('A12:B12').Borders.LineStyle = 1
$ws.Columns.Item('A').ColumnWidth = 24
$ws.Columns.Item('B').ColumnWidth = 18
$ws.Columns.Item('C').ColumnWidth = 12
$ws.Columns.Item('D').ColumnWidth = 96
$ws.Range('B4:B7').NumberFormat = '0.00'
$ws.Range('B4:B7').Interior.ColorIndex = -4142
$ws.Range('C4:C7').Interior.ColorIndex = -4142
$ws.Range('A1:D12').Font.Name = 'Microsoft YaHei'

$button = $ws.Buttons().Add(120, 200, 110, 30)
$button.Caption = 'Calculate'
$button.OnAction = 'CalculatePsychrometrics'

$button2 = $ws.Buttons().Add(245, 200, 80, 30)
$button2.Caption = 'Clear'
$button2.OnAction = 'ResetPsychrometrics'

$vbaModule = @'
Option Explicit

Private Const P_ATM As Double = 101.325
Private Const RATIO As Double = 0.621945

Public Sub CalculatePsychrometrics()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("PsychroTool")

    Application.EnableEvents = False
    On Error GoTo CleanFail

    ClearOldOutputs ws

    Dim hasT As Boolean, hasRH As Boolean, hasW As Boolean, hasTd As Boolean
    Dim T As Double, RH As Double, W As Double, Td As Double
    Dim inputCount As Long

    ReadInput ws.Range("B4"), hasT, T, inputCount
    ReadInput ws.Range("B5"), hasRH, RH, inputCount
    ReadInput ws.Range("B6"), hasW, W, inputCount
    ReadInput ws.Range("B7"), hasTd, Td, inputCount

    If inputCount <> 2 Then
        MsgBox "Please enter exactly two values in B4:B7 before calculating.", vbExclamation, "Two inputs required"
        GoTo CleanExit
    End If

    If hasRH Then
        If RH <= 0 Or RH > 100 Then
            MsgBox "Relative humidity must be a percentage from 0 to 100.", vbExclamation, "Input out of range"
            GoTo CleanExit
        End If
    End If

    If hasW Then
        If W < 0 Then
            MsgBox "Humidity ratio cannot be negative.", vbExclamation, "Input out of range"
            GoTo CleanExit
        End If
        W = W / 1000#
    End If

    Dim pv As Double

    If hasT And hasRH Then
        pv = RH / 100# * PsatKPa(T)
        W = HumidityRatioFromPv(pv)
        Td = DewPointFromPv(pv)
        WriteOutput ws.Range("B6"), W * 1000#, ws.Range("C6")
        WriteOutput ws.Range("B7"), Td, ws.Range("C7")

    ElseIf hasT And hasW Then
        pv = PvFromHumidityRatio(W)
        RH = pv / PsatKPa(T) * 100#
        Td = DewPointFromPv(pv)
        If RH > 100.0001 Then
            MsgBox "This air temperature and humidity ratio imply relative humidity above 100%. Please check the inputs.", vbExclamation, "Inputs may be inconsistent"
            GoTo CleanExit
        End If
        WriteOutput ws.Range("B5"), RH, ws.Range("C5")
        WriteOutput ws.Range("B7"), Td, ws.Range("C7")

    ElseIf hasT And hasTd Then
        pv = PsatKPa(Td)
        RH = pv / PsatKPa(T) * 100#
        W = HumidityRatioFromPv(pv)
        If RH > 100.0001 Then
            MsgBox "Dew point cannot be higher than air temperature. Please check the inputs.", vbExclamation, "Inputs may be inconsistent"
            GoTo CleanExit
        End If
        WriteOutput ws.Range("B5"), RH, ws.Range("C5")
        WriteOutput ws.Range("B6"), W * 1000#, ws.Range("C6")

    ElseIf hasRH And hasW Then
        pv = PvFromHumidityRatio(W)
        T = TemperatureFromPvAndRH(pv, RH)
        Td = DewPointFromPv(pv)
        WriteOutput ws.Range("B4"), T, ws.Range("C4")
        WriteOutput ws.Range("B7"), Td, ws.Range("C7")

    ElseIf hasRH And hasTd Then
        pv = PsatKPa(Td)
        T = TemperatureFromPvAndRH(pv, RH)
        W = HumidityRatioFromPv(pv)
        WriteOutput ws.Range("B4"), T, ws.Range("C4")
        WriteOutput ws.Range("B6"), W * 1000#, ws.Range("C6")

    ElseIf hasW And hasTd Then
        MsgBox "Humidity ratio and dew point both describe vapor pressure. They cannot uniquely determine air temperature and relative humidity. Please enter air temperature or relative humidity as one of the two inputs.", vbInformation, "Independent input missing"
        GoTo CleanExit
    End If

    MarkInputs ws

CleanExit:
    Application.EnableEvents = True
    Exit Sub

CleanFail:
    Application.EnableEvents = True
    MsgBox "Calculation failed: " & Err.Description, vbCritical, "Error"
End Sub

Public Sub ResetPsychrometrics()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("PsychroTool")
    Application.EnableEvents = False
    ws.Range("B4:B7").ClearContents
    ws.Range("C4:C7").ClearContents
    ws.Range("B4:C7").Interior.ColorIndex = xlColorIndexNone
    Application.EnableEvents = True
End Sub

Public Sub MarkChangedCell(ByVal Target As Range)
    Dim changed As Range
    Set changed = Intersect(Target, ThisWorkbook.Worksheets("PsychroTool").Range("B4:B7"))
    If changed Is Nothing Then Exit Sub

    Dim cell As Range
    For Each cell In changed
        If Len(cell.Value2) = 0 Then
            cell.Interior.ColorIndex = xlColorIndexNone
            cell.Offset(0, 1).ClearContents
            cell.Offset(0, 1).Interior.ColorIndex = xlColorIndexNone
        Else
            cell.Interior.Color = InputColor()
            cell.Offset(0, 1).Value2 = "Input"
            cell.Offset(0, 1).Interior.Color = InputColor()
        End If
    Next cell
End Sub

Private Sub ReadInput(ByVal cell As Range, ByRef hasValue As Boolean, ByRef result As Double, ByRef inputCount As Long)
    hasValue = False
    If Len(cell.Value2) > 0 Then
        If Not IsNumeric(cell.Value2) Then
            Err.Raise vbObjectError + 100, , cell.Offset(0, -1).Value2 & " must be numeric."
        End If
        hasValue = True
        result = CDbl(cell.Value2)
        inputCount = inputCount + 1
        cell.Interior.Color = InputColor()
        cell.Offset(0, 1).Value2 = "Input"
        cell.Offset(0, 1).Interior.Color = InputColor()
    End If
End Sub

Private Sub WriteOutput(ByVal cell As Range, ByVal value As Double, ByVal statusCell As Range)
    cell.Value2 = WorksheetFunction.Round(value, 2)
    cell.Interior.Color = OutputColor()
    statusCell.Value2 = "Output"
    statusCell.Interior.Color = OutputColor()
End Sub

Private Sub MarkInputs(ByVal ws As Worksheet)
    Dim cell As Range
    For Each cell In ws.Range("B4:B7")
        If Len(cell.Value2) > 0 And cell.Interior.Color <> OutputColor() Then
            cell.Interior.Color = InputColor()
            cell.Offset(0, 1).Value2 = "Input"
            cell.Offset(0, 1).Interior.Color = InputColor()
        End If
    Next cell
End Sub

Private Sub ClearOldOutputs(ByVal ws As Worksheet)
    Dim cell As Range
    For Each cell In ws.Range("B4:B7")
        If cell.Interior.Color = OutputColor() Or cell.Offset(0, 1).Interior.Color = OutputColor() Then
            cell.ClearContents
            cell.Interior.ColorIndex = xlColorIndexNone
            cell.Offset(0, 1).ClearContents
            cell.Offset(0, 1).Interior.ColorIndex = xlColorIndexNone
        End If
    Next cell
End Sub

Private Function InputColor() As Long
    InputColor = RGB(255, 199, 206)
End Function

Private Function OutputColor() As Long
    OutputColor = RGB(198, 239, 206)
End Function

Private Function PsatKPa(ByVal tC As Double) As Double
    If tC >= 0# Then
        PsatKPa = 0.61094 * Exp((17.625 * tC) / (tC + 243.04))
    Else
        PsatKPa = 0.61094 * Exp((22.587 * tC) / (tC + 273.86))
    End If
End Function

Private Function HumidityRatioFromPv(ByVal pv As Double) As Double
    If pv <= 0# Or pv >= P_ATM Then
        Err.Raise vbObjectError + 101, , "Vapor pressure is outside the calculable range."
    End If
    HumidityRatioFromPv = RATIO * pv / (P_ATM - pv)
End Function

Private Function PvFromHumidityRatio(ByVal w As Double) As Double
    PvFromHumidityRatio = P_ATM * w / (RATIO + w)
End Function

Private Function DewPointFromPv(ByVal pv As Double) As Double
    Dim low As Double, high As Double, mid As Double, i As Long
    low = -80#
    high = 100#
    If pv <= PsatKPa(low) Or pv >= PsatKPa(high) Then
        Err.Raise vbObjectError + 102, , "Dew point is outside the -80 to 100 deg C calculable range."
    End If
    For i = 1 To 80
        mid = (low + high) / 2#
        If PsatKPa(mid) < pv Then
            low = mid
        Else
            high = mid
        End If
    Next i
    DewPointFromPv = (low + high) / 2#
End Function

Private Function TemperatureFromPvAndRH(ByVal pv As Double, ByVal rhPct As Double) As Double
    TemperatureFromPvAndRH = DewPointFromPv(pv / (rhPct / 100#))
End Function
'@

$sheetModule = @'
Option Explicit

Private Sub Worksheet_Change(ByVal Target As Range)
    If Intersect(Target, Me.Range("B4:B7")) Is Nothing Then Exit Sub
    If Application.EnableEvents = False Then Exit Sub
    Application.EnableEvents = False
    MarkChangedCell Target
    Application.EnableEvents = True
End Sub
'@

$module = $wb.VBProject.VBComponents.Add(1)
$module.Name = 'PsychrometricsTool'
$module.CodeModule.AddFromString($vbaModule)

$sheetCode = $wb.VBProject.VBComponents.Item($ws.CodeName).CodeModule
$sheetCode.AddFromString($sheetModule)

$ws.Activate()
$ws.Range('B4').Select()
$wb.SaveAs($outputFullPath, 52)
$excel.DisplayAlerts = $true

Write-Output $outputFullPath
