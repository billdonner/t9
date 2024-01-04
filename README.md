#  T9 - interact with the AI

version  0.5.0

replaces Pumper and LieDetector

## AI Mining Process

The AI Mining Process interacts multiple times (and possibly with multiple AIs) to produce a perfect sequence of question blocks for the game Q20K.

### Step 1 - ask the AI to generate question blocks

The Pumper Tempates (system and user) are used to generate an array of JSON blocks about a series of topics from the AI. These blocks are organized by topic and passed to subsequent steps. 

The templates are essentially the system and user panel contents in the OpenAI playground.

The user template can contain multiple sections separated by a line of five stars. Each section is executed as separate request to the AI.

The received blocks are augmented with a generated ID to allow for matching different outputs. 

The augmented blocks are written by default to PUMPER-LOG.JSON

### Step 2 - ask the AI to identify problems in generated data

The Validation Templates (system and user) are used for this phase. The output of this phase is a detailed JSON structure in VALIDATION-LOG.JSON describing the problems in the data; this data will drive utility programs outside this process.

### Step 3 - ask the AI to repair the data

The Repair Templates (system and user) are used for this phase.

For now, we will ignore the output from step 2 on the assumption the ai will itself identify  problems before repairing.

The output file is a stream of repaired JSON blocks in REPAIRED-LOG.JSON 
This file is in precisely the same format as PUMPER-LOG.JSON

### Step 4 - ask the AI to again identify problems in generated data

Hopefully there will be no problems, otherwise we can go back to step 3 or just stop. If going back to step 3 we can rename the REPAIRED-LOG to PUMPER-LOG

## Any Step Can Be Skipped!

It's not always desirable or necessary to run all the steps. Each step can be individually disabled thru the command line.

If Step 1 is skipped an alternative file of previously pumped blocks must be supplied.


## Command Line 
```
OVERVIEW: Chat With AI To Generate Data for Q20K (IOS) App

Step 1 - ask the AI to generate question blocks
Step 2 - ask the AI to identify problems in generated data
Step 3 - ask the AI to repair the data
Step 4 - ask the AI to again identify problems in generated data

USAGE: t9 [<options>] <pumpsys> <pumpusr>

ARGUMENTS:
  <pumpsys>               pumper system template URL
  <pumpusr>               pumper user template URL

OPTIONS:
  --valsys <valsys>       validation system template URL, default is no
                          validation
  --valusr <valusr>       validation user template URL, default is ""
  --repsys <repsys>       repair system template URL, default is no repair
  --repusr <repusr>       repair user template URL, default is ""
  --revalsys <revalsys>   re-validation system template URL, default is no
                          revalidation
  --revalusr <revalusr>   re-validation user template URL, default is ""
  --altpump <altpump>     alternate pumper input URL, default is ""
  --pumpedfile <pumpedfile>
                          pumpedoutput directory of json files
  --repairedfile <repairedfile>
                          repaired directory of json files
  --validatedfile <validatedfile>
                          validated json stream file
  --revalidatedfile <revalidatedfile>
                          revalidated json stream file
  --model <model>         model (default: gpt-4)
  --verbose               verbose
  --looper                keep looping thru pumpusr
  --timeout <timeout>     AI timeout in seconds (default: 120)
  --maxtokens <maxtokens> AI Max TOKENS (default: 4000)
  --version               Show the version.
  -h, --help              Show help information.
  ```
