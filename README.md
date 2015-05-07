# anon-history

This project collects anonymous Wikipedia edits made by governments and industries around the world.

See http://jarib.github.io/anon-history/

## How to update with new Wikipedia data

### Download latest dump

    $ curl --fail -O dumps.wikimedia.org/itwiki/latest/itwiki-latest-stub-meta-history.xml.gz

### Convert to CSV

The convert-to-csv script comes from https://github.com/jarib/wikipedia-edits (which also has lots of unrelated code in it). It could probably be done a lot more efficiently with another langauge runtime.

    $ cat itwiki-latest-stub-meta-history.xml.gz | gunzip | bin/convert-to-csv | gzip > wiki.it.csv.gz

### Upload to Google Storage

    $ gsutil cp wiki.it.csv.gz gs://wikiedits/

### Import to BigQuery table

In the Google BigQuery UI, import `wikis.it.csv.gz` from Google Storage to a table called `wikis.it`.

### Generate and execute query

Clone https://github.com/jarib/anon-history, then create e.g. `/tmp/ranges.json` with ranges in the following format:

```json
{
    "Senato della Repubblica": [
        [
            "5.98.5.176",
            "5.98.5.183"
        ]
    ]
}
```

You can find old ranges in `ItaGovEdits/it/latest/ranges.json` (but with an extra, wrapping object for some reason I can't remember).

Run this command from the anon-history checkout:

    $ scripts/go /tmp/ranges.json ItaGovEdits 'the Italian government' it

Copy the printed query and execute it in the BigQuery UI (https://bigquery.cloud.google.com).
When the query has finished, click "Download as CSV". Move the downloaded file to `ItaGovEdits/it/latest/data.csv`, then press any key to let the script finish.

Remember to update the top-level index.html, which is maintained by hand.



