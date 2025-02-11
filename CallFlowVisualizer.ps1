<#
    .SYNOPSIS
    Reads the configuration from a Microsoft 365 Phone System auto attendant and visualizes the call flow using mermaid-js.

    .DESCRIPTION
    Presents a selection of available auto attendants and then reads the config of that auto attendant and writes it into a mermaid-js flowchart file.

    Author:             Martin Heusser
    Version:            1.0.0
    Revision:
        20.10.2021:     Creation

    .PARAMETER Name
    -docType
        Mandatory=$false
        [String], allowed values: Markdown (default), Mermaid
            Markdown: Creates a markdown file (*.md) with mermaid code declaration
            Mermaid: Creates a mermaid file (*.mmd)

    .INPUTS
    - Auto Attendant Name (through Out-GridView)

    .OUTPUTS
    - Mermaid flowchart

    .EXAMPLE

    .LINK
    https://github.com/mozziemozz/M365CallFlowVisualizer
#>

#Requires -Modules MsOnline, MicrosoftTeams

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][ValidateSet("Markdown","Mermaid")][String]$docType = "Markdown"
)

$resourceAccount = Get-CsOnlineApplicationInstance | Where-Object {$_.PhoneNumber -notlike "" -and $_.ApplicationId -eq "ce933385-9390-45d1-9512-c8d228074e07"} | Select-Object DisplayName, PhoneNumber, ObjectId | Out-GridView -PassThru -Title "Choose an Auto Attendant from the list to visualize your call flow:"

$aaProperties = New-Object -TypeName psobject

$aaProperties | Add-Member -MemberType NoteProperty -Name "PhoneNumber" -Value $($resourceAccount.PhoneNumber).Replace("tel:","")

$aa = Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $resourceAccount.ObjectId}

$aaProperties | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $aa.Name

####Check if AA has holidays
if ($aa.CallHandlingAssociations.Type.Value -contains "Holiday") {

    $aaHasHolidays = $true

    $aaHolidays = $aa.CallHandlingAssociations | Where-Object {$_.Type -match "Holiday" -and $_.Enabled -eq $true}

    $mdSubGraphHolidays =@"
subgraph Holidays
    direction LR
"@

########The counter is here so that each element is unique in Mermaid
    $HolidayCounter = 1
    
    foreach ($HolidayCallHandling in $aaHolidays) {

        $holidayCallFlow = $aa.CallFlows | Where-Object {$_.Id -eq $HolidayCallHandling.CallFlowId}
        $holidaySchedule = $aa.Schedules | Where-Object {$_.Id -eq $HolidayCallHandling.ScheduleId}

        if (!$holidayCallFlow.Greetings) {

            $holidayGreeting = "Greeting <br> None"

        }

        else {

            $holidayGreeting = "Greeting <br> $($holidayCallFlow.Greetings.ActiveType.Value)"

        }

        $holidayAction = $holidayCallFlow.Menu.MenuOptions.Action.Value

        if ($holidayAction -eq "DisconnectCall") {

            $nodeElementHolidayAction = "elementAAHolidayAction$($HolidayCounter)(($holidayAction))"

        }

        else {

            $holidayActionTargetType = $holidayCallFlow.Menu.MenuOptions.CallTarget.Type.Value

            switch ($holidayActionTargetType) {
                User { $holidayActionTargetTypeFriendly = "User" 
                $holidayActionTargetName = (Get-MsolUser -ObjectId $($holidayCallFlow.Menu.MenuOptions.CallTarget.Id)).DisplayName
            }
                SharedVoicemail { $holidayActionTargetTypeFriendly = "Voicemail"
                $holidayActionTargetName = (Get-MsolGroup -ObjectId $($holidayCallFlow.Menu.MenuOptions.CallTarget.Id)).DisplayName
            }
                ExternalPstn { $holidayActionTargetTypeFriendly = "External Number" 
                $holidayActionTargetName =  ($holidayCallFlow.Menu.MenuOptions.CallTarget.Id).Replace("tel:","")
            }
                ApplicationEndpoint {                    
                $MatchingAA = Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $holidayCallFlow.Menu.MenuOptions.CallTarget.Id}

                    if ($MatchingAA) {

                        $holidayActionTargetTypeFriendly = "[Auto Attendant"
                        $holidayActionTargetName = "$($MatchingAA.Name)]"

                    }

                    else {

                        $MatchingCQ = Get-CsCallQueue | Where-Object {$_.ApplicationInstances -eq $holidayCallFlow.Menu.MenuOptions.CallTarget.Id}

                        $holidayActionTargetTypeFriendly = "[Call Queue"
                        $holidayActionTargetName = "$($MatchingCQ.Name)]"

                    }

                }
            
            }

            $nodeElementHolidayAction = "elementAAHolidayAction$($HolidayCounter)($holidayAction) --> elementAAHolidayActionTargetType$($HolidayCounter)($holidayActionTargetTypeFriendly <br> $holidayActionTargetName)"

        }

        $nodeElementHolidayDetails =@"
        
        subgraph $($holidayCallFlow.Name)
        direction LR
        elementAAHoliday$($HolidayCounter)(Schedule <br> $($holidaySchedule.FixedSchedule.DateTimeRanges.Start) <br> $($holidaySchedule.FixedSchedule.DateTimeRanges.End)) --> elementAAHolidayGreeting$($HolidayCounter)>$holidayGreeting] --> $nodeElementHolidayAction
            end
"@

        $HolidayCounter ++

        $mdSubGraphHolidays += $nodeElementHolidayDetails

    }

    $mdSubGraphHolidaysEnd =@"

end
"@

$mdSubGraphHolidays += $mdSubGraphHolidaysEnd

}

else {

    $aaHasHolidays = $false

}

$aaDefaultScheduleProperties = New-Object -TypeName psobject

$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "ComplementEnabled" -Value $true
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "MondayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "TuesdayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "WednesdayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "ThursdayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "FridayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "SaturdayHours" -Value "00:00:00-1.00:00:00"
$aaDefaultScheduleProperties | Add-Member -MemberType NoteProperty -Name "SundayHours" -Value "00:00:00-1.00:00:00"

$aaDefaultScheduleProperties = $aaDefaultScheduleProperties | Out-String

$aaAfterHoursScheduleProperties = ($aa.Schedules | Where-Object {$_.name -match "after"}).WeeklyRecurrentSchedule | Out-String

if ($aaDefaultScheduleProperties -eq $aaAfterHoursScheduleProperties) {

    $aaHasAfterHours = $false

}

else {

    $aaHasAfterHours = $true

    $aaBusinessHours = ($aa.Schedules | Where-Object {$_.name -match "after"}).WeeklyRecurrentSchedule | ConvertTo-Csv

    $aaBusinessHoursFriendly = $aaBusinessHours | ConvertFrom-Csv

    # Monday
    if ($aaBusinessHoursFriendly.DisplayMondayHours -eq "00:00:00-1.00:00:00") {
        $mondayHours = "Monday Hours: Open 24 hours"
    } 
    elseif ($aaBusinessHoursFriendly.DisplayMondayHours) {
        $mondayHours = "Monday Hours: $($aaBusinessHoursFriendly.DisplayMondayHours)"
    }
    else {
        $mondayHours = "Monday Hours: Closed"
    }

    # Tuesday
    if ($aaBusinessHoursFriendly.DisplayTuesdayHours -eq "00:00:00-1.00:00:00") {
        $TuesdayHours = "Tuesday Hours: Open 24 hours"
    }
    elseif ($aaBusinessHoursFriendly.DisplayTuesdayHours) {
        $TuesdayHours = "Tuesday Hours: $($aaBusinessHoursFriendly.DisplayTuesdayHours)"
    } 
    else {
        $TuesdayHours = "Tuesday Hours: Closed"
    }

    # Wednesday
    if ($aaBusinessHoursFriendly.DisplayWednesdayHours -eq "00:00:00-1.00:00:00") {
        $WednesdayHours = "Wednesday Hours: Open 24 hours"
    } 
    elseif ($aaBusinessHoursFriendly.DisplayWednesdayHours) {
        $WednesdayHours = "Wednesday Hours: $($aaBusinessHoursFriendly.DisplayWednesdayHours)"
    }
    else {
        $WednesdayHours = "Wednesday Hours: Closed"
    }

    # Thursday
    if ($aaBusinessHoursFriendly.DisplayThursdayHours -eq "00:00:00-1.00:00:00") {
        $ThursdayHours = "Thursday Hours: Open 24 hours"
    } 
    elseif ($aaBusinessHoursFriendly.DisplayThursdayHours) {
        $ThursdayHours = "Thursday Hours: $($aaBusinessHoursFriendly.DisplayThursdayHours)"
    }
    else {
        $ThursdayHours = "Thursday Hours: Closed"
    }

    # Friday
    if ($aaBusinessHoursFriendly.DisplayFridayHours -eq "00:00:00-1.00:00:00") {
        $FridayHours = "Friday Hours: Open 24 hours"
    } 
    elseif ($aaBusinessHoursFriendly.DisplayFridayHours) {
        $FridayHours = "Friday Hours: $($aaBusinessHoursFriendly.DisplayFridayHours)"
    }
    else {
        $FridayHours = "Friday Hours: Closed"
    }

    # Saturday
    if ($aaBusinessHoursFriendly.DisplaySaturdayHours -eq "00:00:00-1.00:00:00") {
        $SaturdayHours = "Saturday Hours: Open 24 hours"
    } 

    elseif ($aaBusinessHoursFriendly.DisplaySaturdayHours) {
        $SaturdayHours = "Saturday Hours: $($aaBusinessHoursFriendly.DisplaySaturdayHours)"
    }

    else {
        $SaturdayHours = "Saturday Hours: Closed"
    }

    # Sunday
    if ($aaBusinessHoursFriendly.DisplaySundayHours -eq "00:00:00-1.00:00:00") {
        $SundayHours = "Sunday Hours: Open 24 hours"
    }
    elseif ($aaBusinessHoursFriendly.DisplaySundayHours) {
        $SundayHours = "Sunday Hours: $($aaBusinessHoursFriendly.DisplaySundayHours)"
    }
 
    else {
        $SundayHours = "Sunday Hours: Closed"
    }

    $nodeElementAfterHoursCheck = "elementAfterHoursCheck{During Business Hours? <br> $mondayHours <br> $tuesdayHours  <br> $wednesdayHours  <br> $thursdayHours <br> $fridayHours <br> $saturdayHours <br> $sundayHours}"

}

if ($docType -eq "Markdown") {

$mdStart =@"
``````mermaid
flowchart TB
"@

$mdEnd =@"

``````
"@

$fileExtension = ".md"

}

else {

$mdStart =@"
flowchart TB
"@

$mdEnd =@"

"@

$fileExtension = ".mmd"

}

$mdYes =@"
-->|Yes|
"@

$mdNo =@"
-->|No|
"@

$nodeStart = "start((Incoming Call at <br> $($aaProperties.PhoneNumber)))"
$nodeElementAA = "elementAA([Auto Attendant <br> $($aaProperties.DisplayName)])"

$nodeElementHolidayCheck = "elementHolidayCheck{During Holiday?}"

$defaultCallFlow = $aa.DefaultCallFlow
$defaultCallFlowAction = $aa.DefaultCallFlow.Menu.MenuOptions.Action.Value

$defaultCallFlowGreeting = "Greeting <br> $($defaultCallFlow.Greetings.ActiveType.Value)"

if ($defaultCallFlowAction -eq "TransferCallToTarget") {

$defaultCallFlowTargetType = $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Type.Value

switch ($defaultCallFlowTargetType) {
    User { 
        $defaultCallFlowTargetTypeFriendly = "User"
        $defaultCallFlowTargetName = (Get-MsolUser -ObjectId $($aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id)).DisplayName}
    ExternalPstn { 
        $defaultCallFlowTargetTypeFriendly = "External PSTN"
        $defaultCallFlowTargetName = ($aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id).Replace("tel:","")}
    ApplicationEndpoint {

        $MatchingAA = Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id}

        if ($MatchingAA) {

            $defaultCallFlowTargetTypeFriendly = "[Auto Attendant"
            $defaultCallFlowTargetName = "$($MatchingAA.Name)]"

        }

        else {

            $MatchingCQ = Get-CsCallQueue | Where-Object {$_.ApplicationInstances -eq $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id}

            $cqAssociatedApplicationInstance = Get-CsOnlineApplicationInstance -Identity $MatchingCQ.DisplayApplicationInstances

            if ($cqAssociatedApplicationInstance.PhoneNumber) {

                $defaultCallFlowcCqIsTopLevel = "start2((Incoming Call at <br> $($cqAssociatedApplicationInstance.PhoneNumber))) -...-> defaultCallFlowAction"

            }

            else {
                
                $defaultCallFlowcCqIsTopLevel = $null
            }

            $defaultCallFlowTargetTypeFriendly = "[Call Queue"
            $defaultCallFlowTargetName = "$($MatchingCQ.Name)]"

        }

    }
    SharedVoicemail {

        $defaultCallFlowTargetTypeFriendly = "Voicemail"
        $defaultCallFlowTargetName = (Get-MsolGroup -ObjectId $aa.DefaultCallFlow.Menu.MenuOptions.CallTarget.Id).DisplayName

    }
}


if ($defaultCallFlowTargetTypeFriendly -eq "[Call Queue") {

    $CqOverFlowThreshold = $MatchingCQ.OverflowThreshold
    $CqOverFlowAction = $MatchingCQ.OverflowAction.Value
    $CqTimeOut = $MatchingCQ.TimeoutThreshold
    $CqTimeoutAction = $MatchingCQ.TimeoutAction.Value
    $CqRoutingMethod = $MatchingCQ.RoutingMethod.Value
    $CqAgents = $MatchingCQ.Agents.ObjectId
    $CqAgentOptOut = $MatchingCQ.AllowOptOut
    $CqConferenceMode = $MatchingCQ.ConferenceMode
    $CqAgentAlertTime = $MatchingCQ.AgentAlertTime
    $CqPresenceBasedRouting = $MatchingCQ.PresenceBasedRouting
    $CqDistributionList = $MatchingCQ.DistributionLists
    $CqDefaultMusicOnHold = $MatchingCQ.UseDefaultMusicOnHold
    $CqWelcomeMusicFileName = $MatchingCQ.WelcomeMusicFileName

    switch ($CqOverFlowAction) {
        DisconnectWithBusy {
            $CqOverFlowActionFriendly = "cqOverFlowAction((Disconnect Call))"
        }
        Forward {

            if ($MatchingCQ.OverflowActionTarget.Type -eq "User") {

                $MatchingOverFlowUser = (Get-MsolUser -ObjectId $MatchingCQ.OverflowActionTarget.Id).DisplayName

                $CqOverFlowActionFriendly = "cqOverFlowAction(TransferCallToTarget) --> cqOverFlowActionTarget(User <br> $MatchingOverFlowUser)"

            }

            elseif ($MatchingCQ.OverflowActionTarget.Type -eq "Phone") {

                $cqOverFlowPhoneNumber = ($MatchingCQ.OverflowActionTarget.Id).Replace("tel:","")

                $CqOverFlowActionFriendly = "cqOverFlowAction(TransferCallToTarget) --> cqOverFlowActionTarget(External Number <br> $cqOverFlowPhoneNumber)"
                
            }

            else {

                $MatchingOverFlowAA = (Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $MatchingCQ.OverflowActionTarget.Id}).Name

                if ($MatchingOverFlowAA) {

                    $CqOverFlowActionFriendly = "cqOverFlowAction(TransferCallToTarget) --> cqOverFlowActionTarget([Auto Attendant <br> $MatchingOverFlowAA])"

                }

                else {

                    $MatchingOverFlowCQ = (Get-CsCallQueue | Where-Object {$_.ApplicationInstances -eq $MatchingCQ.OverflowActionTarget.Id}).Name

                    $CqOverFlowActionFriendly = "cqOverFlowAction(TransferCallToTarget) --> cqOverFlowActionTarget([Call Queue <br> $MatchingOverFlowCQ])"

                }

            }

        }
        SharedVoicemail {
            $MatchingOverFlowVoicemail = (Get-MsolGroup -ObjectId $MatchingCQ.OverflowActionTarget.Id).DisplayName

            if ($MatchingCQ.OverflowSharedVoicemailTextToSpeechPrompt) {

                $CqOverFlowVoicemailGreeting = "TextToSpeech"

            }

            else {

                $CqOverFlowVoicemailGreeting = "AudioFile"

            }

            $CqOverFlowActionFriendly = "cqOverFlowAction(TransferCallToTarget) --> cqOverFlowVoicemailGreeting>Greeting <br> $CqOverFlowVoicemailGreeting] --> cqOverFlowActionTarget(Shared Voicemail <br> $MatchingOverFlowVoicemail)"

        }

    }

    switch ($CqTimeoutAction) {
        DisconnectWithBusy {
            $CqTimeoutActionFriendly = "cqTimeoutAction((Disconnect Call))"
        }
        Forward {
    
            if ($MatchingCQ.TimeoutActionTarget.Type -eq "User") {

                $MatchingTimeoutUser = (Get-MsolUser -ObjectId $MatchingCQ.TimeoutActionTarget.Id).DisplayName
    
                $CqTimeoutActionFriendly = "cqTimeoutAction(TransferCallToTarget) --> cqTimeoutActionTarget(User <br> $MatchingTimeoutUser)"
    
            }
    
            elseif ($MatchingCQ.TimeoutActionTarget.Type -eq "Phone") {
    
                $cqTimeoutPhoneNumber = ($MatchingCQ.TimeoutActionTarget.Id).Replace("tel:","")
    
                $CqTimeoutActionFriendly = "cqTimeoutAction(TransferCallToTarget) --> cqTimeoutActionTarget(External Number <br> $cqTimeoutPhoneNumber)"
                
            }
    
            else {
    
                $MatchingTimeoutAA = (Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $MatchingCQ.TimeoutActionTarget.Id}).Name
    
                if ($MatchingTimeoutAA) {
    
                    $CqTimeoutActionFriendly = "cqTimeoutAction(TransferCallToTarget) --> cqTimeoutActionTarget([Auto Attendant <br> $MatchingTimeoutAA])"
    
                }
    
                else {
    
                    $MatchingTimeoutCQ = (Get-CsCallQueue | Where-Object {$_.ApplicationInstances -eq $MatchingCQ.TimeoutActionTarget.Id}).Name
    
                    $CqTimeoutActionFriendly = "cqTimeoutAction(TransferCallToTarget) --> cqTimeoutActionTarget([Call Queue <br> $MatchingTimeoutCQ])"
    
                }
    
            }
    
        }
        SharedVoicemail {
            $MatchingTimeoutVoicemail = (Get-MsolGroup -ObjectId $MatchingCQ.TimeoutActionTarget.Id).DisplayName
    
            if ($MatchingCQ.TimeoutSharedVoicemailTextToSpeechPrompt) {
    
                $CqTimeoutVoicemailGreeting = "TextToSpeech"
    
            }
    
            else {
    
                $CqTimeoutVoicemailGreeting = "AudioFile"
    
            }
    
            $CqTimeoutActionFriendly = "cqTimeoutAction(TransferCallToTarget) --> cqTimeoutVoicemailGreeting>Greeting <br> $CqTimeoutVoicemailGreeting] --> cqTimeoutActionTarget(Shared Voicemail <br> $MatchingTimeoutVoicemail)"
    
        }
    
    }

    if ($CqDefaultMusicOnHold -eq $true) {

        $CqMusicOnHold = "Default"
    }

    else {

        $CqMusicOnHold = "Custom"

    }

    if (!$CqWelcomeMusicFileName) {

        $CqGreeting = "None"

    }

    else {

        $CqGreeting = "Audio File"

    }

    if (!$CqDistributionList) {

        $CqAgentListType = "Users"

    }

    else {

        if (!$MatchingCQ.ChannelId) {

            $CqAgentListType = "Group"

        }

        else {

            $CqAgentListType = "Teams Channel"

        }

    }

    $mdCqAgentsDisplayNames = @"
"@

    $AgentCounter = 1

    foreach ($CqAgent in $CqAgents) {
        $AgentDisplayName = (Get-MsolUser -ObjectId $CqAgent).DisplayName

        $AgentDisplayNames = "agentListType --> agent$($AgentCounter)($AgentDisplayName) --> timeOut`n"

        $mdCqAgentsDisplayNames += $AgentDisplayNames

        $AgentCounter ++
    }

    $defaultCallFlowMarkDown =@"
--> defaultCallFlow($defaultCallFlowAction) --> defaultCallFlowAction($defaultCallFlowTargetTypeFriendly <br> $defaultCallFlowTargetName) --> cqGreeting>Greeting <br> $CqGreeting]
--> overFlow{More than $CqOverFlowThreshold <br> Active Calls}
overFlow --> |Yes| $CqOverFlowActionFriendly
overFlow --> |No| routingMethod

$defaultCallFlowcCqIsTopLevel

subgraph Call Distribution
    subgraph CQ Settings
    routingMethod[(Routing Method: $CqRoutingMethod)] --> agentAlertTime
    agentAlertTime[(Agent Alert Time: $CqAgentAlertTime)] -.- cqMusicOnHold
    cqMusicOnHold[(Music On Hold: $CqMusicOnHold)] -.- conferenceMode
    conferenceMode[(Conference Mode Enabled: $CqConferenceMode)] -.- agentOptOut
    agentOptOut[(Agent Opt Out Allowed: $CqAgentOptOut)] -.- presenceBasedRouting
    presenceBasedRouting[(Presence Based Routing: $CqPresenceBasedRouting)] -.- timeOut
    timeOut[(Timeout: $CqTimeOut Seconds)]
    end
    subgraph Agents
    agentAlertTime --> agentListType[(Agent List Type: $CqAgentListType)]
    $mdCqAgentsDisplayNames
    end
end

timeOut --> cqResult{Call Connected?}
    cqResult --> |Yes| cqEnd((Call Connected))
    cqResult --> |No| $CqTimeoutActionFriendly

"@
    
}

else {

    $defaultCallFlowMarkDown = "--> defaultCallFlow($defaultCallFlowAction) --> defaultCallFlowAction($defaultCallFlowTargetTypeFriendly <br> $defaultCallFlowTargetName)"

}

}

elseif ($defaultCallFlowAction -eq "DisconnectCall") {

$defaultCallFlowMarkDown = "--> defaultCallFlow(($defaultCallFlowAction))"

}

$mdDefaultCallflow =@"
defaultCallFlowGreeting>$defaultCallFlowGreeting] $defaultCallFlowMarkDown
"@

$afterHoursCallFlow = ($aa.CallFlows | Where-Object {$_.Name -Match "after hours"})
$afterHoursCallFlowAction = ($aa.CallFlows | Where-Object {$_.Name -Match "after hours"}).Menu.MenuOptions.Action.Value


$afterHoursCallFlowGreeting = "Greeting <br> $($afterHoursCallFlow.Greetings.ActiveType.Value)"

if ($afterHoursCallFlowAction -eq "TransferCallToTarget") {

$afterHoursCallFlowTargetType = $afterHoursCallFlow.Menu.MenuOptions.CallTarget.Type.Value

switch ($afterHoursCallFlowTargetType) {
    User { 
        $afterHoursCallFlowTargetTypeFriendly = "User"
        $afterHoursCallFlowTargetName = (Get-MsolUser -ObjectId $($afterHoursCallFlow.Menu.MenuOptions.CallTarget.Id)).DisplayName}
    ExternalPstn { 
        $afterHoursCallFlowTargetTypeFriendly = "External PSTN"
        $afterHoursCallFlowTargetName = ($afterHoursCallFlow.Menu.MenuOptions.CallTarget.Id).Replace("tel:","")}
    ApplicationEndpoint {

        $MatchingAA = Get-CsAutoAttendant | Where-Object {$_.ApplicationInstances -eq $afterHoursCallFlow.Menu.MenuOptions.CallTarget.Id}

        if ($MatchingAA) {

            $afterHoursCallFlowTargetTypeFriendly = "[Auto Attendant"
            $afterHoursCallFlowTargetName = "$($MatchingAA.Name)]"

        }

        else {

            $MatchingCQ = Get-CsCallQueue | Where-Object {$_.ApplicationInstances -eq $afterHoursCallFlow.Menu.MenuOptions.CallTarget.Id}

            $afterHoursCallFlowTargetTypeFriendly = "[Call Queue"
            $afterHoursCallFlowTargetName = "$($MatchingCQ.Name)]"

        }

    }
    SharedVoicemail {

        $afterHoursCallFlowTargetTypeFriendly = "Voicemail"
        $afterHoursCallFlowTargetName = (Get-MsolGroup -ObjectId $afterHoursCallFlow.Menu.MenuOptions.CallTarget.Id).DisplayName

    }
}

$afterHoursCallFlowMarkDown = "--> afterHoursCallFlow($afterHoursCallFlowAction) --> afterHoursCallFlowAction($afterHoursCallFlowTargetTypeFriendly <br> $afterHoursCallFlowTargetName)"

}

elseif ($afterHoursCallFlowAction -eq "DisconnectCall") {

$afterHoursCallFlowMarkDown = "--> afterHoursCallFlow(($afterHoursCallFlowAction))"

}

$mdAfterHoursCallFlow =@"
afterHoursCallFlowGreeting>$afterHoursCallFlowGreeting] $afterHoursCallFlowMarkDown
"@

if ($aaHasHolidays) {

####AA Has Holidays and After Hours
if ($aaHasAfterHours) {
$mdContent =@"
$nodeStart --> $nodeElementAA --> 
$nodeElementHolidayCheck $mdYes Holidays
$nodeElementHolidayCheck $mdNo $nodeElementAfterHoursCheck
    $nodeElementAfterHoursCheck $mdYes $mdDefaultCallflow
    $nodeElementAfterHoursCheck $mdNo $mdAfterHoursCallFlow

$mdSubGraphHolidays

"@
}

####AA has no after hours but holidays
else {
$mdContent =@"
$nodeStart --> $nodeElementAA --> $nodeElementHolidayCheck
$nodeElementHolidayCheck $mdYes Holidays
$nodeElementHolidayCheck $mdNo $mdDefaultCallflow

$mdSubGraphHolidays

"@
}

}

#if AA has no Holidays but after hours
else {

if ($aaHasAfterHours) {
$mdContent =@"
$nodeStart --> $nodeElementAA --> $nodeElementAfterHoursCheckCheck
$nodeElementAfterHoursCheck $mdYes $mdDefaultCallflow
$nodeElementAfterHoursCheck $mdNo $mdAfterHoursCallFlow

"@
}

####If aa has no after hours and no holidays
else {
$mdContent =@"
$nodeStart --> $nodeElementAA --> $mdDefaultCallflow

"@
}

}


Set-Content -Path ".\$($aa.Name)_CallFlow$fileExtension" -Value $mdStart, $mdContent, $mdEnd -Encoding UTF8

