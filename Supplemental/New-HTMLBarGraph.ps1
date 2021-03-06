function New-HTMLBarGraph {
    <#
    .SYNOPSIS
    Creates an HTML fragment that looks like a horizontal bar graph when rendered.
    .DESCRIPTION
    Creates an HTML fragment that looks like a horizontal bar graph when rendered. Can be customized to use different
    characters for the left and right sides of the graph. Can also be customized to be a certain number of characters
    in size (Highly recommend sticking with even numbers)
    .PARAMETER LeftGraphChar
    HTML encoded character to use for the left part of the graph (the percentage used).
    .PARAMETER RightGraphChar
    HTML encoded character to use for the right part of the graph (the percentage unused).
    .PARAMETER GraphSize
    Overall character size of the graph
    .PARAMETER PercentageUsed
    The percentage of the graph which is "used" (the left side of the graph).
    .PARAMETER LeftColor
    The HTML color code for the left/used part of the graph.
    .PARAMETER RightColor
    The HTML color code for the right/unused part of the graph.
    .EXAMPLE
    PS> New-HTMLBarGraph -GraphSize 20 -PercentageUsed 10

    <Font Color=Red>&#9608;&#9608;</Font>
    <Font Color=Green>&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;
    &#9608;&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;
    &#9608;&#9608;</Font>

    .NOTES
    Author: Zachary Loeber
    Site: http://www.the-little-things.net/
    Requires: Powershell 2.0
    Version History:
       1.0.0 - 08/10/2013
        - Initial release
        
    Some good characters to use for your graphs include:
    ▬  &#9644;
    ░  &#9617; {dither light}    
    ▒  &#9618; {dither medium}    
    ▓  &#9619; {dither heavy}    
    █  &#9608; {full box}

    Find more html character codes here: http://brucejohnson.ca/SpecialCharacters.html

    The default colors are not all that impressive. Used (left side of graph) is red and unused 
    (right side of the graph) is green. You use any colors which the font attribute will accept in html, 
    this includes transparent!

    If you are including this output in a larger table with other results remember that the 
    special characters will get converted and look all crappy after piping through convertto-html.
    To fix this issue, simply html decode the results like in this long winded example for memory
    utilization:

    $a = gwmi win32_operatingSystem | `
    select PSComputerName, @{n='Memory Usage';
                             e={New-HTMLBarGraph -GraphSize 20 -PercentageUsed `
                               (100 - [math]::Round((100 * ($_.FreePhysicalMemory)/`
                                                           ($_.TotalVisibleMemorySize))))}
                            }
    $Output = [System.Web.HttpUtility]::HtmlDecode(($a | ConvertTo-Html))
    $Output

    Props for original script from http://windowsmatters.com/index.php/category/powershell/page/2/
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage='Character to use for left side of graph')]
        [string]$LeftGraphChar='&#9608;',
        [Parameter(HelpMessage='Character to use for right side of graph')]
        [string]$RightGraphChar='&#9608;',
        [Parameter(HelpMessage='Total size of the graph in character length. You really should stick with even numbers here.')]
        [int]$GraphSize=50,
        [Parameter(HelpMessage="Percentage for first part of graph")]
        [int]$PercentageUsed=50,
        [Parameter(HelpMessage="Color of left (used) graph segment.")]
        [string]$LeftColor='Red',
        [Parameter(HelpMessage="Color of left (unused) graph segment.")]
        [string]$RightColor='Green'
    )

    [int]$LeftSideCount = [Math]::Round((($PercentageUsed/100)*$GraphSize))
    [int]$RightSideCount = [Math]::Round((((100 - $PercentageUsed)/100)*$GraphSize))
    for ($index = 0; $index -lt $LeftSideCount; $index++)
    {
        $LeftSide = $LeftSide + $LeftGraphChar
    }
    for ($index = 0; $index -lt $RightSideCount; $index++)
    {
        $RightSide = $RightSide + $RightGraphChar
    }
    
    $Result = "<Font Color={0}>{1}</Font><Font Color={2}>{3}</Font>" `
               -f $LeftColor,$LeftSide,$RightColor,$RightSide

    return $Result
}