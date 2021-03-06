# Shamelessly used code from the following sources:
# XenApp Environment Report Script:
#   http://carlwebster.com/where-to-get-copies-of-the-documentation-scripts/
# Lync Environment Report Script:
#   http://gallery.technet.microsoft.com/office/Lync-Environment-Report-cbc6fb1a
# ConvertTo-MultiArray (for really fast excel worksheet creation)
#   http://powertoe.wordpress.com
function ConvertTo-MultiArray {
    <#
    .Notes
        NAME: ConvertTo-MultiArray
        AUTHOR: Tome Tanasovski
        Website: http://powertoe.wordpress.com
        Twitter: http://twitter.com/toenuff
    #>
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [PSObject[]]$InputObject
    )
    begin {
        $objects = @()
        [ref]$array = [ref]$null
    }
    process {
        $objects += $InputObject
    }
    end {
        $properties = $objects[0].psobject.properties |%{$_.name}
        $array.Value = New-Object 'object[,]' ($objects.Count+1),$properties.count
        # i = row and j = column
        $j = 0
        $properties |%{
            $array.Value[0,$j] = $_.tostring()
            $j++
        }
        $i = 1
        $objects |% {
            $item = $_
            $j = 0
            $properties | % {
                if ($item.($_) -eq $null) {
                    $array.value[$i,$j] = ""
                }
                else {
                    $array.value[$i,$j] = $item.($_).tostring()
                }
                $j++
            }
            $i++
        }
        $array
    }
}

function New-ExcelWorkbook {
    [CmdletBinding()] 
    param (
        [Parameter(HelpMessage='Make the workbook visible (or not).')]
        [bool]
        $Visible = $true
    )
    try {
        $ExcelApp = New-Object -ComObject 'Excel.Application'
        $ExcelApp.DisplayAlerts = $false
    	$ExcelWorkbook = $ExcelApp.Workbooks.Add()
    	$ExcelApp.Visible = $Visible

        # Store the old culture for later restoration.
        $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
        
        # Set base culture
        ([System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US') | Out-Null

        $DisplayAlerts = $ExcelApp.DisplayAlerts
        $ExcelApp.DisplayAlerts = $false

        $ExcelProps = 
        @{
            'Application' = $ExcelApp
            'Workbook' = $ExcelWorkbook
            'Worksheets' = $ExcelWorkbook.Worksheets
            'CurrentSheetNumber' = 1
            'CurrentWorksheet' = $ExcelWorkbook.Worksheets.Item(1)
            'OldCulture' = $OldCulture
            'Saved' = $false
            'DisplayAlerts' = $DisplayAlerts
            'CurrentTabColor' = 20
        }
        $NewWorkbook = New-Object -TypeName PsObject -Property $ExcelProps
        $NewWorkbook | Add-Member -MemberType ScriptMethod -Name SaveAs -Value {
            param (
                [Parameter( HelpMessage='Report file name.')]
                [string]
                $FileName = 'report.xlsx'
            )
            try
            {
                $this.Workbook.SaveAs($FileName)
                $this.Saved = $true
            }
            catch
            {
                Write-Warning "Report was unable to be saved as $FileName"
                $this.Saved = $false
            }
        }
        $NewWorkbook | Add-Member -MemberType ScriptMethod -Name CloseWorkbook -Value {
            try
            {
                $this.Application.DisplayAlerts = $this.DisplayAlerts
                $this.Workbook.Save()
                $this.Application.Quit()
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $this.OldCulture
                
                # Truly release the com object, otherwise it will linger like a bad ghost
                [system.Runtime.InteropServices.marshal]::ReleaseComObject($this.Application) | Out-Null
                
                # Perform garbage collection
                [gc]::collect()
                [gc]::WaitForPendingFinalizers()
            }
            catch
            {
                Write-Warning ('There was an issue closing the excel workbook: {0}' -f $_.Exception.Message)
            }
        }
        $NewWorkbook | Add-Member -MemberType ScriptMethod -Name RemoveWorksheet -Value {
            param (
                [Parameter( HelpMessage='Worksheet to delete.')]
                [string]
                $WorksheetName = 'Sheet1'
            )
            if ($this.Workbook.Worksheets.Count -gt 1)
            {
                $WorkSheets = ($this.Worksheets | Select Name).Name
                if ($WorkSheets -contains $WorksheetName)
                {
                    $this.Worksheets.Item("$WorksheetName").Delete()
                }
            }
        }
        $NewWorkbook | Add-Member -MemberType ScriptMethod -Name NewWorksheet -Value {
            param (
                [Parameter(Mandatory=$true,
                           HelpMessage='New worksheet name.')]
                [string]
                $WorksheetName,
                [Parameter(Mandatory=$false,
                           HelpMessage='Use new tab color.')]
                [bool]
                $NewTabColor = $true
            )

            if ($this.CurrentSheetNumber -gt $this.WorkSheets.Count)
            {
			    $this.CurrentWorkSheet = $this.WorkSheets.Add()
    		} 
            else 
            {
    			$this.CurrentWorkSheet = $this.WorkSheets.Item($this.CurrentSheetNumber)
    		}
            $this.CurrentSheetNumber++
            if ($NewTabColor)
            {
                $this.CurrentWorkSheet.Tab.ColorIndex = $this.CurrentTabColor
            	$this.CurrentTabColor += 1
            	if ($script:TabColor -ge 55)
                {
                    $this.CurrentTabColor = 1
                }
               # $this.CurrentWorksheet = $This.WorkSheets.Add()
            }
            $this.CurrentWorksheet.Name = $WorksheetName
        }
        $NewWorkbook | Add-Member -MemberType ScriptMethod -Name NewWorksheetFromArray -Value {
            param (
                    [Parameter(Mandatory=$true,
                               HelpMessage='Array of objects.')]
                    $InputObjArray,
                    [Parameter(Mandatory=$true,
                               HelpMessage='Worksheet Name.')]
                    [string]
                    $WorksheetName
                )
                $AllObjects = @()
                $AllObjects += $InputObjArray
                $ObjArray = $InputObjArray | ConvertTo-MultiArray
                if ($ObjArray -ne $null)
                {
                    $temparray = $ObjArray.Value
                    $starta = [int][char]'a' - 1
                    
                    if ($temparray.GetLength(1) -gt 26) 
                    {
                        $col = [char]([int][math]::Floor($temparray.GetLength(1)/26) + $starta) + [char](($temparray.GetLength(1)%26) + $Starta)
                    } 
                    else 
                    {
                        $col = [char]($temparray.GetLength(1) + $starta)
                    }
                    
                    Start-Sleep -s 1
                    $xlCellValue = 1
                    $xlEqual = 3
                    $BadColor = 13551615    #Light Red
                    $BadText = -16383844    #Dark Red
                    $GoodColor = 13561798    #Light Green
                    $GoodText = -16752384    #Dark Green
                    
                    $this.NewWorksheet($WorksheetName,$true)
                    $Range = $this.CurrentWorksheet.Range("a1","$col$($temparray.GetLength(0))")
                    $Range.Value2 = $temparray

                    #Format the end result (headers, autofit, et cetera)
                    $Range.EntireColumn.AutoFit() | Out-Null
                    $Range.FormatConditions.Add($xlCellValue,$xlEqual,'TRUE') | Out-Null
                    $Range.FormatConditions.Item(1).Interior.Color = $GoodColor
                    $Range.FormatConditions.Item(1).Font.Color = $GoodText
                    $Range.FormatConditions.Add($xlCellValue,$xlEqual,'OK') | Out-Null
                    $Range.FormatConditions.Item(2).Interior.Color = $GoodColor
                    $Range.FormatConditions.Item(2).Font.Color = $GoodText
                    $Range.FormatConditions.Add($xlCellValue,$xlEqual,'FALSE') | Out-Null
                    $Range.FormatConditions.Item(3).Interior.Color = $BadColor
                    $Range.FormatConditions.Item(3).Font.Color = $BadText
                    
                    # Header
                    $Range = $this.CurrentWorksheet.Range("a1","$($col)1")
                    $Range.Interior.ColorIndex = 19
                    $Range.Font.ColorIndex = 11
                    $Range.Font.Bold = $True
                    $Range.HorizontalAlignment = -4108
                    
                    # Table styling
                    $objList = ($this.CurrentWorkSheet.ListObjects).Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $this.CurrentWorkSheet.UsedRange, $null,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes,$null)
                    $objList.TableStyle = "TableStyleMedium20"
                    
                    # Auto fit the columns
                    $this.CurrentWorkSheet.UsedRange.Columns.Autofit() | Out-Null
                }
        }
        Return $NewWorkbook
	}
    catch
    {
        Write-Warning 'New-ExcelWorkbook: There was an issue instantiating the new excel workbook, is MS excel installed?'
        Write-Warning ('New-ExcelWorkbook: {0}' -f $_.Exception.Message)
    }
}

function New-WordDocument {
    [CmdletBinding()] 
    param (
        [Parameter(HelpMessage='Make the document visible (or not).')]
        [bool]$Visible = $true,
        [Parameter(HelpMessage='Company name for cover page.')]
        [string]$CompanyName='Contoso Inc.',
        [Parameter(HelpMessage='Document title for cover page.')]
        [string]$DocTitle = 'Your Report',
        [Parameter(HelpMessage='Document subject for cover page.')]
        [string]$DocSubject = 'A great Word report.',
        [Parameter(HelpMessage='User name for cover page.')]
        [string]$DocUserName = $env:username
    )
    try {
        $WordApp = New-Object -ComObject 'Word.Application'
        $WordVersion = [int]$WordApp.Version
        switch ($WordVersion) {
        	15 {
                write-verbose 'New-WordDocument: Running Microsoft Word 2013'
                $WordProduct = 'Word 2013'
        	}
        	14 {
                write-verbose 'New-WordDocument: Running Microsoft Word 2010'
                $WordProduct = 'Word 2010'
        	}
        	12 {
                write-verbose 'New-WordDocument: Running Microsoft Word 2007'
                $WordProduct = 'Word 2007'
        	}
            11 {
                write-verbose 'New-WordDocument: Running Microsoft Word 2003'
                $WordProduct = 'Word 2003'
            }
        }

    	# Create a new blank document to work with and make the Word application visible.
    	$WordDoc = $WordApp.Documents.Add()
    	$WordApp.Visible = $Visible

        # Store the old culture for later restoration.
        $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
        
        # May speed things up when creating larger docs
        # $SpellCheckSetting = $WordApp.Options.CheckSpellingAsYouType
        $GrammarCheckSetting = $WordApp.Options.CheckGrammarAsYouType
        $WordApp.Options.CheckSpellingAsYouType = $False
        $WordApp.Options.CheckGrammarAsYouType = $False
        
        # Set base culture
        ([System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US') | Out-Null

        $WordProps = @{
            'CompanyName' = $CompanyName
            'Title' = $DocTitle
            'Subject' = $DocSubject
            'Username' = $DocUserName
            'Application' = $WordApp
            'Document' = $WordDoc
            'Selection' = $WordApp.Selection
            'OldCulture' = $OldCulture
            'SpellCheckSetting' = $SpellCheckSetting
            'GrammarCheckSetting' = $GrammarCheckSetting
            'WordVersion' = $WordVersion
            'WordProduct' = $WordProduct
            'TableOfContents' = $null
            'Saved' = $false
        }
        $NewDoc = New-Object -TypeName PsObject -Property $WordProps
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewLine -Value {
            param (
                [Parameter( HelpMessage='Number of lines to instert.')]
                [int]
                $lines = 1
            )
            for ($index = 0; $index -lt $lines; $index++) {
            	($this.Selection).TypeParagraph()
            }
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name SaveAs -Value {
            param (
                [Parameter( HelpMessage='Report file name.')]
                [string]
                $WordDocFileName = 'report.docx'
            )
            try {
                $this.Document.SaveAs([ref]$WordDocFileName)
                $this.Saved = $true
            }
            catch {
                Write-Warning "Report was unable to be saved as $WordDocFileName"
                $this.Saved = $false
            }
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewText -Value {
            param (
                [Parameter( HelpMessage='Text to instert.')]
                [string]$text = ''
            )
            ($this.Selection).TypeText($text)
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewPageBreak -Value {
            ($this.Selection).InsertNewPage()
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name MoveToEnd -Value {
            ($this.Selection).Start = (($this.Selection).StoryLength - 1)
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewCoverPage -Value {
            param (
                [Parameter( HelpMessage='Coverpage Template.')]
                [string]$CoverPage = 'Facet'
            )
            # Go back to the beginning of the document
        	$this.Selection.GoTo(1, 2, $null, 1) | Out-Null
            [bool]$CoverPagesExist = $False
            [bool]$BuildingBlocksExist = $False

            $this.Application.Templates.LoadBuildingBlocks()
            if ($this.WordVersion -eq 12) # Word 2007
            {
            	$BuildingBlocks = $this.Application.Templates | Where {$_.name -eq 'Building Blocks.dotx'}
            }
            else
            {
            	$BuildingBlocks = $this.Application.Templates | Where {$_.name -eq 'Built-In Building Blocks.dotx'}
            }

            Write-Verbose "$(Get-Date): Attempt to load cover page $($CoverPage)"
            $part = $Null

            if ($BuildingBlocks -ne $Null)
            {
                $BuildingBlocksExist = $True

            	try {
                    Write-Verbose 'New-WordDocument(NewCoverPage): Setting Coverpage'
                    $part = $BuildingBlocks.BuildingBlockEntries.Item($CoverPage)
                }
            	catch {
                    $part = $Null
                }

            	if ($part -ne $Null)
            	{
                    $CoverPagesExist = $True
            	}
            }

            if ($CoverPagesExist)
            {
            	Write-Verbose "New-WordDocument(NewCoverPage): Set Cover Page Properties"
            	$this.SetDocProp($this.document.BuiltInDocumentProperties, 'Company', $this.CompanyName)
                $this.SetDocProp($this.document.BuiltInDocumentProperties, 'Title', $this.Title)
            	$this.SetDocProp($this.document.BuiltInDocumentProperties, 'Subject', $this.Subject)
            	$this.SetDocProp($this.document.BuiltInDocumentProperties, 'Author', $this.Username)
            
                #Get the Coverpage XML part
            	$cp = $this.Document.CustomXMLParts | where {$_.NamespaceURI -match "coverPageProps$"}

            	#get the abstract XML part
            	$ab = $cp.documentelement.ChildNodes | Where {$_.basename -eq "Abstract"}
            	[string]$abstract = "$($this.Title) for $($this.CompanyName)"
                $ab.Text = $abstract

            	$ab = $cp.documentelement.ChildNodes | Where {$_.basename -eq "PublishDate"}
            	[string]$abstract = (Get-Date -Format d).ToString()
            	$ab.Text = $abstract
                
                $part.Insert($this.Selection.Range,$True) | out-null
	            $this.Selection.InsertNewPage()
            }
            else
            {
                $this.NewLine(5)
                $this.Selection.Style = "Title"
                $this.Selection.ParagraphFormat.Alignment = "wdAlignParagraphCenter"
                $this.Selection.TypeText($this.Title)
                $this.NewLine()
                $this.Selection.ParagraphFormat.Alignment = "wdAlignParagraphCenter"
                $this.Selection.Font.Size = 24
                $this.Selection.TypeText($this.Subject)
                $this.NewLine()
                $this.Selection.ParagraphFormat.Alignment = "wdAlignParagraphCenter"
                $this.Selection.Font.Size = 18
                $this.Selection.TypeText("Date: $(get-date)")
                $this.NewPageBreak()
            }
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewBlankPage -Value {
            param (
                [Parameter(HelpMessage='Cover page sub-title')]
                [int]
                $NumberOfPages
            )
            for ($i = 0; $i -lt $NumberOfPages; $i++){
		        $this.Selection.Font.Size = 11
		        $this.Selection.ParagraphFormat.Alignment = "wdAlignParagraphLeft"
		        $this.NewPageBreak()
	        }
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewTable -Value {
            param (
                [Parameter(HelpMessage='Rows')]
                [int]
                $NumRows=1,
                [Parameter(HelpMessage='Columns')]
                [int]
                $NumCols=1,
                [Parameter(HelpMessage='Include first row as header')]
                [bool]
                $HeaderRow = $true
            )
        	$NewTable = $this.Document.Tables.Add($this.Selection.Range, $NumRows, $NumCols)
        	$NewTable.AllowAutofit = $true
        	$NewTable.AutoFitBehavior(2)
        	$NewTable.AllowPageBreaks = $false
        	$NewTable.Style = "Grid Table 4 - Accent 1"
        	$NewTable.ApplyStyleHeadingRows = $HeaderRow
        	return $NewTable
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewTableFromArray -Value {
            param (
                [Parameter(Mandatory=$true,
                           HelpMessage='Array of objects.')]
                $ObjArray,
                [Parameter(HelpMessage='Include first row as header')]
                [bool] $HeaderRow = $true
            )
            $AllObjects = @()
            $AllObjects += $ObjArray
            if ($HeaderRow)
            {
                $TableToInsert = ($AllObjects | ConvertTo-Csv -NoTypeInformation | Out-String) -replace '"',''
            }
            else
            {
                $TableToInsert = ($AllObjects | ConvertTo-Csv -NoTypeInformation | Select -Skip 1 | Out-String) -replace '"',''
            }
            $Range = $this.Selection.Range
            $Range.Text = "$TableToInsert"
            $Separator = [Microsoft.Office.Interop.Word.WdTableFieldSeparator]::wdSeparateByCommas
            $NewTable = $Range.ConvertToTable($Separator)
            $NewTable.AutoFormat([Microsoft.Office.Interop.Word.WdTableFormat]::wdTableFormatElegant)
            $NewTable.AllowAutofit = $true
        	$NewTable.AutoFitBehavior(2)
        	$NewTable.AllowPageBreaks = $false
        	$NewTable.Style = "Grid Table 4 - Accent 1"
        	$NewTable.ApplyStyleHeadingRows = $true
        	return $NewTable
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewBookmark -Value {
            param (
                [Parameter(Mandatory=$true,
                           HelpMessage='A bookmark name')]
                [string]$BookmarkName
            )
        	$this:Document.Bookmarks.Add($BookmarkName,$this.Selection)
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name SetDocProp -Value {
        	#jeff hicks
        	Param(
                [object]$Properties,
                [string]$Name,
                [string]$Value
            )
        	#get the property object
        	$prop = $properties | ForEach { 
        		$propname=$_.GetType().InvokeMember("Name","GetProperty",$Null,$_,$Null)
        		if($propname -eq $Name) 
        		{
        			Return $_
        		}
        	}

        	#set the value
        	$Prop.GetType().InvokeMember("Value","SetProperty",$Null,$prop,$Value)
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewHeading -Value {
            param(
                [string]$Label = '', 
                [string]$Style = 'Heading 1'
            )
        	$this.Selection.Style = $Style
        	$this.Selection.TypeText($Label)
        	$this.Selection.TypeParagraph()
        	$this.Selection.Style = "Normal"
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name NewTOC -Value {
            param (
                [Parameter(Mandatory=$true,
                           HelpMessage='A number to instert your table of contents into.')]
                [int]$PageNumber = 2,
                [string]$TOCHeading = 'Table of Contents',
                [string]$TOCHeaderStyle = 'Heading 1'
            )
            # Go back to the beginning of page two.
        	$this.Selection.GoTo(1, 2, $null, $PageNumber) | Out-Null
        	$this.NewHeading($TOCHeading,$TOCHeaderStyle)
        	
        	# Create Table of Contents for document.
        	# Set Range to beginning of document to insert the Table of Contents.
        	$TOCRange = $this.Selection.Range
        	$useHeadingStyles = $true
        	$upperHeadingLevel = 1 # <-- Heading1 or Title 
        	$lowerHeadingLevel = 2 # <-- Heading2 or Subtitle 
        	$useFields = $false
        	$tableID = $null
        	$rightAlignPageNumbers = $true
        	$includePageNumbers = $true
            
        	# to include any other style set in the document add them here 
        	$addedStyles = $null
        	$useHyperlinks = $true
        	$hidePageNumbersInWeb = $true
        	$useOutlineLevels = $true

        	# Insert Table of Contents
        	$TableOfContents = $this.Document.TablesOfContents.Add($TocRange, $useHeadingStyles, 
                               $upperHeadingLevel, $lowerHeadingLevel, $useFields, $tableID, 
                               $rightAlignPageNumbers, $includePageNumbers, $addedStyles, 
                               $useHyperlinks, $hidePageNumbersInWeb, $useOutlineLevels)
        	$TableOfContents.TabLeader = 0
            $this.TableOfContents = $TableOfContents
            $this.MoveToEnd()
        }
        $NewDoc | Add-Member -MemberType ScriptMethod -Name CloseDocument -Value {
            try {
                # $WordObject.Application.Options.CheckSpellingAsYouType = $WordObject.SpellCheckSetting
                $this.Application.Options.CheckGrammarAsYouType = $this.GrammarCheckSetting
                $this.Document.Save()
                $this.Application.Quit()
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $this.OldCulture
                
                
                # Truly release the com object, otherwise it will linger like a bad ghost
                [system.Runtime.InteropServices.marshal]::ReleaseComObject($this.Application) | Out-Null
                
                # Perform garbage collection
                [gc]::collect()
                [gc]::WaitForPendingFinalizers()
            }
            catch {
                Write-Warning 'New-WordDocument(CloseDocument): There was an issue closing the word document.'
                Write-Warning ('New-WordDocument(CloseDocument): {0}' -f $_.Exception.Message)
            }
        }
        Return $NewDoc
	}
    catch {
        Write-Error 'New-WordDocument: There was an issue instantiating the new word document, is MS word installed?'
        Write-Error ('New-WordDocument: {0}' -f $_.Exception.Message)
        Throw "New-WordDocument: Problems creating new word document"
    }
}

##### Example Code #####
$testdata = Get-Process | 
             Select-Object Handle,ID,Name,@{'n'='TrueProperty';e={$true}},@{'n'='FalseProperty';e={$false}} | 
             Select-Object -first 20
try {
    # Word test. Create and then save and close a new document with a few tables, a table of contents, and 
    #  cover page.
    $Word = New-WordDocument -Visible $true
    $Word.NewCoverPage()
    $Word.NewBlankPage(1)
    $Word.MoveToEnd()
    $Word.NewPageBreak()
    $Word.NewHeading('Section 1')
    $Word.NewText('Just testing out if this works...')
    $Word.NewTable(4,10) | Out-Null
    $Word.MoveToEnd()
    $Word.NewPageBreak()
    $Word.NewHeading('Section 2')
    $testtable = $Word.NewTableFromArray($testdata) # | Out-Null
    $Word.NewTOC()
    $Word.SaveAs('c:\Temp\testdoc.docx')
    $Word.CloseDocument()
    Remove-Variable word
}
catch {
    Write-Error "Issue creating word document"
}

try {
    # Excel test. Create and then save and close a new workbook.
    $excel = New-ExcelWorkbook -Visible $false
    $excel.NewWorksheetFromArray($testdata,'Processes')
    $excel.NewWorksheetFromArray($testdata,'Duplicate of Processes')
    $excel.SaveAs('c:\temp\testexcel.xlsx')
    $excel.CloseWorkbook()
    Remove-Variable excel
}
catch {
    Write-Error "Issue creating excel document"
}