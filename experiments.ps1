# Log in to the website and store the session in "WebSession"

# Initialise a session
$result = Invoke-WebRequest -Uri $BaseURI -SessionVariable WebSession -UseBasicParsing
 #Fill in the login form
    $Form= @{
        '[edit-name]' = $loginName
        '[edit-password]' = $loginPassword
    }
#Login
$result = Invoke-WebRequest -uri $BaseURI -Body $form -WebSession $WebSession -Method Post -UseBasicParsing 
exit


#Now to run a report
# Query parameters look like this but will be URL encoded below (TODO - URL Encode a set of query parameters)
<#
$Query = @{
    'field_trap_record_date_value[min][date]' = "1 May 2020"
    'field_trap_record_date_value[max][date]' = "6 Jun 2021"
}

#>

[URI]$BaseURI = "https://trap.nz/my-projects/reports/trap-records?field_trap_record_date_value%5Bmin%5D%5Bdate%5D=1+May+2020&field_trap_record_date_value%5Bmax%5D%5Bdate%5D=6+Jun+2021&items_per_page=20"
$traprecords = Invoke-WebRequest -uri $BaseURI -WebSession $WebSession -Method Get -UseBasicParsing

$traprecords
#Element 7 of the links part of the data returned from the page contains a URL where you can download a csv of the data
$traprecords.Links[7].href

exit

#next launch the URL to start a CSV download


[URI]$BaseURI = "https://trap.nz$($traprecords.Links[7].href)"
$traprecords = Invoke-WebRequest -uri $BaseURI -WebSession $WebSession -Method Get -UseBasicParsing

# The page contains a Batch ID for the CSV data that will be generated so put the batch ID in a variable
$id = Select-String 'URL=/batch\?id\=(.*)(&amp)' -InputObject $traprecords.RawContent
$BatchID = $id.Matches.groups[1].value

exit

# In the brownser, the page redirects itself to a URL with a Get method and parameters op=start id=$BatchID
# The page then redirects to another url with a Post method and parameters op=do id=$BatchID
# This page then reloads about once per second and a progress bar is observed progressing, there is hidden content contains a percentage complete and a message
# When the progress reaches 100% there is a redirect to a url with Get method and parameters op=finished id=$batchid
# The "finished" page contains a URL with a couple of parameters EID={number} Token={string of characers} in a browser this page downloads the csv automatically but also has a link to manually download


 
# Start the batch
[URI]$URI = "https://trap.nz/batch?op=start&id=$BatchID"
$BatchStart = Invoke-WebRequest -URI $URI -Method Get -WebSession $WebSession -UseBasicParsing
$BatchStart.Content

#Do the batch repeatedly until it reaches 100%
[URI]$URI = "https://trap.nz/batch?id=$BatchID&op=do"
$BatchProgress = Invoke-WebRequest -URI $URI -Method Post -WebSession $WebSession -UseBasicParsing 
$BatchProgress.RawContent
# Note that in the script, it instantly reaches 100% which is probably a lie

        # The script showed that op=do_nojs was a possible value but it seems to act the same as op=do
        [URI]$URI = "https://trap.nz/batch?id=$BatchID&op=do_nojs"
        $BatchProgress = Invoke-WebRequest -URI $URI -Method Post -WebSession $WebSession -UseBasicParsing 
        $BatchProgress.RawContent

# When the do is 100% Finished  
[URI]$URI = "https://trap.nz/batch?id=$BatchID&op=finished"
$BatchFinished = Invoke-WebRequest -URI $URI -Method Get -WebSession $WebSession -UseBasicParsing
$BatchFinished.RawContent
# Links section, index 7 contains the url to download the file including the eid and token
$BatchFinished.Links[7].href

#Store the EID and Token in variables because, why not?
$DownloadInfo = Select-String ';eid\=(.*)(&amp;)(token\=)(.*)(")' -InputObject $BatchFinished.RawContent
$EID = $DownloadInfo.Matches.Groups[1].Value
$Token = $DownloadInfo.Matches.Groups[4].Value

#Try and download the CSV
[URI]$DownloadURI = "https://trap.nz$($BatchFinished.Links[7].href)"
$output = Invoke-WebRequest -Uri $DownloadURI -WebSession $WebSession -Method Get -UseBasicParsing 
#Marvel at the CSV with a row of column headings and nothing else
