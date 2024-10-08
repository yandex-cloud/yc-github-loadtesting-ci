# GitHub Actions for Yandex Cloud Load Testing service

[USAGE EXAMPLE](.github/workflows/example.yml)

[USAGE EXAMPLE WORKFLOW](https://github.com/yandex-cloud/yc-github-loadtesting-ci/actions/workflows/example.yml)

**NOTE**: All actions require `auth-key-json` to authorize requests to Yandex Cloud services. Please check <a href="https://yandex.cloud/en/docs/iam/operations/authorized-key/create#cli_1" target="_blank">this documentation page</a> for instructions how to create one.

## Short reference

* **test-suite** - execute multiple load tests sequentially
* **agents-create** - create and start load testing agents using Yandex Cloud Compute VMs as a hosting (Compute is billed separately)
* **agents-delete** - delete load testing agents
* **test-single-run** - execute a single load test
* **test-single-check** - check results of a single load test

## Action: `test-suite`
```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/test-suite@main
```

Execute and assess a bunch of tests in a single action step.

Each test is specified by a separate directory containing:
- `test-config.yaml` test configuration file
- (optional) `meta.json` json file specifying test properties
- (optional) additional test data files which will be transferred to the agent via `data-bucket`

A list of directories containing `test-config.yaml` test configuration files should be provided via `test-directories` input parameter.

**NOTE**: Why `data-bucket` is needed? Test data files often contain sensitive information such as access tokens and customer data. Using `data-bucket` as a proxy storage guarantees that this sensitive information never gets stored elsewhere.

<!--doc-begin-test-suite-->
### Inputs
|Input|Description|Default|Required|
|-----|-----------|-------|:------:|
|`folder-id`|ID of a folder in Yandex Cloud.|n/a|yes|
|`auth-key-json-base64`|<p>BASE64 encoded authorized key string in JSON format. This setting is preferred over <code>auth-key-json</code>.</p><p>The action will perform all operations on behalf of a service account for which this authorized key was generated.</p><p>Given a json file, encode it via command line <code>base64 &lt;authorized_key.json &gt;authorized_key.pem</code> and add the content of result file to GitHub secrets.</p>|n/a|no|
|`auth-key-json`|<p>Use 'auth-key-json-base64'.</p><p>An authorized key string in JSON format.</p><p>The use of this parameter is discouraged because it can lead to unwanted logs obfuscation (see <a href="https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets">naming your secrets</a>).</p>|``|no|
|`action-log-level`|Action log level.|`NOTICE`|no|
|`data-bucket`|<p>Bucket used as a proxy storage to send arbitrary test data needed for test execution to agent.</p><p><strong>WARNING</strong>:<br />CI service account (authorized via auth-key-json(-base64)) must be able to upload data to this bucket</p><p><strong>WARNING2</strong>:<br />agent service account must be able to download data from this bucket.</p>|``|no|
|`artifacts-bucket`|<p>Bucket to store artifacts generated by agent during test execution.</p><p><strong>WARNING</strong>:<br />agent service account must be able to upload data to this bucket.</p>|``|no|
|`test-directories`|A whitespace-separated list of directory paths containing test configuration files.|n/a|yes|
|`agent-filter`|<p>A filter expression to select agents to execute tests.</p><p>Example:<br />  - 'name contains github' - agents with 'github' substring in name.<br />  - 'labels.workflow=$WORKFLOW_ID' - agents with label 'workflow' equals to $WORKFLOW_ID</p>|`labels.workflow=${{ github.run_id }}`|no|
|`add-description`|Specified string will be added to description of created tests.|`Run from GitHub Actions`|no|
|`add-labels`|Specified labels will be added to label set of created tests. Format: 'key1=value1,key2=value2'.|`ci=github`|no|
### Outputs
|Output|Description|
|------|-----------|
|`test-ids`|IDs of performed tests.|
|`test-infos-file`|File containing a JSON array of objects with information about performed tests.|
|`test-infos`|JSON array of objects with information about performed tests.|
|`execution-report-file`|Path to generated .md execution report file.|
|`checks-report-file`|Path to generated .md checks report file.|
|`artifacts-dir`|Action artifacts directory. If needed, save it using actions/upload_artifacts.|
<!--doc-end-test-suite-->

### Required roles
- `loadtesting.loadTester` - to create and run the test
- `storage.uploader` - to upload test data to Object Storage (required, if `data-bucket` is specified)

### Example
```yaml
- uses: actions/checkout@v4
- uses: yandex-cloud/yc-github-loadtesting-ci/test-suite@main
  with:
    folder-id: ${{ vars.YC_FOLDER_ID }}
    auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
    test-directories: |-
      _impl/testdata/http-const-rps
      _impl/testdata/https-const-rps
```

## Action: `agents-create`
```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
```

Create agents alongside with Cloud Compute VMs to host them.
  
This action is usually used used in pair with 'agents-delete' action.

**NOTE**: For security reasons you should create new service account with 'loadtesting.generatorClient' role to assign to loadtesting agent (see `service-account-id` input below) 

<!--doc-begin-agents-create-->
### Inputs
|Input|Description|Default|Required|
|-----|-----------|-------|:------:|
|`folder-id`|ID of a folder in Yandex Cloud.|n/a|yes|
|`auth-key-json-base64`|<p>BASE64 encoded authorized key string in JSON format. This setting is preferred over <code>auth-key-json</code>.</p><p>The action will perform all operations on behalf of a service account for which this authorized key was generated.</p><p>Given a json file, encode it via command line <code>base64 &lt;authorized_key.json &gt;authorized_key.pem</code> and add the content of result file to GitHub secrets.</p>|n/a|no|
|`auth-key-json`|<p>Use 'auth-key-json-base64'.</p><p>An authorized key string in JSON format.</p><p>The use of this parameter is discouraged because it can lead to unwanted logs obfuscation (see <a href="https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets">naming your secrets</a>).</p>|``|no|
|`action-log-level`|Action log level.|`NOTICE`|no|
|`count`|Number of agents to be created.|`1`|no|
|`service-account-id`|<p>ID of a service account to create agent VM with.</p><p>The service account must have 'loadtesting.generatorClient' role.</p>|``|no|
|`vm-zone`|Compute zone to create agent VM in.|`ru-central1-d`|no|
|`name-prefix`|<p>If count=0, a name of created agent.<br />if count&gt;0, a name prefix of created agents.</p>|`onetime-ci-agent`|no|
|`description`|Description of created agents.|`Create from Github Actions`|no|
|`labels`|Labels of created agents. Format: 'key1=value1,key2=value2'.|`workflow=${{ github.run_id }}`|no|
|`cli-args`|<p>Additional command line arguments to be passed to <code>yc loadtesting agent create</code><br />(see <code>yc loadtesting agent create -h</code> for more details).</p><p>Override rules:<br />* '--zone ARG' overrides 'vm-zone' input parameter<br />* '--service-account-id ARG' overrides 'service-account-id' input parameter<br />* '--network-interface' overrides default network interface settings (which is - 1-to-1 NAT (dynamic public IP) in automatically chosen subnet)<br />* '--name ARG' overrides 'name-prefix' input parameter<br />* '--description ARG' overrides 'description' input parameter<br />* '--labels' overrides 'labels' input parameter</p>|``|no|
|`timeout`|<p>Time to wait for agents to become READY_FOR_TEST.</p><p>Usually, reaching this timeout means either missing permissions or invalid agent network settings.</p>|`600`|no|
### Outputs
|Output|Description|
|------|-----------|
|`agent-ids`|IDs of created agents.|
|`artifacts-dir`|Action artifacts directory. If needed, save it using actions/upload_artifacts.|
<!--doc-end-agents-create-->

### Required roles
- `loadtesting.loadTester` - to create an agent
- `compute.editor` - to create and start agent VM
- `iam.serviceAccounts.user` - to assign service account to agent VM
- `vpc.user` - to configure network interface on agent VM
- `vpc.publicAdmin` - to configure public IP on agent VM (the default way, may be omitted if you know what you are doing)

### Examples

**Simple:**

```yaml
# - 2 CPU, 2 GB RAM
# - one-to-one NAT in an automatically selected subnet

uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}
  labels: "workflow=${{ github.run_id }}"
  # count: 1
  # vm-zone: ru-central1-a
```

<details><summary>Custom CPU and RAM settings:</summary>

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}
  labels: "workflow=${{ github.run_id }}"
  cli-args: |-
    --cores 2
    --memory 2G
  # count: 1
  # vm-zone: ru-central1-a
```

</details>

<details><summary>Custom network settings:</summary>

This version is essentially identical to `yc loadtesting agent create ${cli-args}`.

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
  cli-args: |-
    --service-account-id "${{ vars.YC_LOADTESTING_SA_ID }}"
    --labels "workflow=${{ github.run_id }}"
    --cores 2
    --memory 2G
    --zone 'ru-central1-a'
    --network-settings "subnet-name=default-a,security-group-ids=${{ vars.YC_LOADTESTING_AGENT_SECURITY_GROUP_ID }}"
  # count: 1
```

</details>

## Action: `agents-delete`
```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-delete@main
```

Delete agents (and the VMs).

This action is usually used used in pair with 'agents-create' action.

<!--doc-begin-agents-delete-->
### Inputs
|Input|Description|Default|Required|
|-----|-----------|-------|:------:|
|`folder-id`|ID of a folder in Yandex Cloud.|n/a|yes|
|`auth-key-json-base64`|<p>BASE64 encoded authorized key string in JSON format. This setting is preferred over <code>auth-key-json</code>.</p><p>The action will perform all operations on behalf of a service account for which this authorized key was generated.</p><p>Given a json file, encode it via command line <code>base64 &lt;authorized_key.json &gt;authorized_key.pem</code> and add the content of result file to GitHub secrets.</p>|n/a|no|
|`auth-key-json`|<p>Use 'auth-key-json-base64'.</p><p>An authorized key string in JSON format.</p><p>The use of this parameter is discouraged because it can lead to unwanted logs obfuscation (see <a href="https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets">naming your secrets</a>).</p>|``|no|
|`action-log-level`|Action log level.|`NOTICE`|no|
|`agent-ids`|<p>A string containing whitespace-separated list of agents to be deleted.</p><p>Normally, should be used with conjunction with <code>agents-create.outputs.agent-ids</code>.</p>|n/a|yes|
### Outputs
|Output|Description|
|------|-----------|
|`artifacts-dir`|Action artifacts directory. If needed, save it using actions/upload_artifacts.|
<!--doc-end-agents-delete-->

### Required roles
- `loadtesting.loadTester` - to delete an agent
- `compute.editor` - to stop and delete agent VM

### Example

This action is usually used in pair with `agents-create` action:

```yaml
loadtesting:
  name: loadtesting job
  runs-on: ubuntu-latest
  steps:
    - id: create-agents
      uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
      with:
        folder-id: ${{ vars.YC_FOLDER_ID }}
        auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
        service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}
    #
    # here we run some tests on created agents
    # - id: run-test
    #   ...
    #
    - id: delete-agents
      if: always() # make sure delete is called even if previous steps fail
      uses: yandex-cloud/yc-github-loadtesting-ci/agents-delete@main
      with:
        folder-id: ${{ vars.YC_FOLDER_ID }}
        auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

        # pass created agent ids to make sure they are deleted
        agent-ids: ${{ steps.agent-create.outputs.agent-ids }}
```

## Action: `test-single-run`
```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/test-single-run@main
```

Execute a single test.

Each test should be specified by a separate directory containing:
- `test-config.yaml` test configuration file
- (optional) `meta.json` json file specifying test properties
- (optional) additional test data files which will be transferred to the agent via `data-bucket` 

A directory containing `test-config.yaml` test configuration file should be provided via `test-directory` input parameter.

**NOTE**: Why `data-bucket` is needed? Test data files often contain sensitive information such as access tokens and customer data. Using `data-bucket` as a proxy storage guarantees that this sensitive information never gets stored elsewhere.

<!--doc-begin-test-single-run-->
### Inputs
|Input|Description|Default|Required|
|-----|-----------|-------|:------:|
|`folder-id`|ID of a folder in Yandex Cloud.|n/a|yes|
|`auth-key-json-base64`|<p>BASE64 encoded authorized key string in JSON format. This setting is preferred over <code>auth-key-json</code>.</p><p>The action will perform all operations on behalf of a service account for which this authorized key was generated.</p><p>Given a json file, encode it via command line <code>base64 &lt;authorized_key.json &gt;authorized_key.pem</code> and add the content of result file to GitHub secrets.</p>|n/a|no|
|`auth-key-json`|<p>Use 'auth-key-json-base64'.</p><p>An authorized key string in JSON format.</p><p>The use of this parameter is discouraged because it can lead to unwanted logs obfuscation (see <a href="https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets">naming your secrets</a>).</p>|``|no|
|`action-log-level`|Action log level.|`NOTICE`|no|
|`data-bucket`|<p>Bucket used as a proxy storage to send arbitrary test data needed for test execution to agent.</p><p><strong>WARNING</strong>:<br />CI service account (authorized via auth-key-json(-base64)) must be able to upload data to this bucket</p><p><strong>WARNING2</strong>:<br />agent service account must be able to download data from this bucket.</p>|``|no|
|`artifacts-bucket`|<p>Bucket to store artifacts generated by agent during test execution.</p><p><strong>WARNING</strong>:<br />agent service account must be able to upload data to this bucket.</p>|``|no|
|`test-directory`|A path to a directory containing test configuration files.|n/a|yes|
|`agent-filter`|<p>A filter expression to select agents to execute tests.</p><p>Example:<br />  - 'name contains github' - agents with 'github' substring in name.<br />  - 'labels.workflow=$WORKFLOW_ID' - agents with label 'workflow' equals to $WORKFLOW_ID</p>|`labels.workflow=${{ github.run_id }}`|no|
|`add-description`|Specified string will be added to description of created tests.|`Run from GitHub Actions`|no|
|`add-labels`|Specified labels will be added to label set of created tests. Format: 'key1=value1,key2=value2'.|`ci=github`|no|
### Outputs
|Output|Description|
|------|-----------|
|`test-id`|ID of performed test.|
|`test-info-file`|File containing a JSON object with information about performed test.|
|`test-info`|JSON object with information about performed test.|
|`report-file`|Path to generated .md report file.|
|`artifacts-dir`|Action artifacts directory. If needed, save it using actions/upload_artifacts.|
<!--doc-end-test-single-run-->

### Required roles
- `loadtesting.loadTester` - to create and run the test
- `storage.uploader` - to upload test data to Object Storage (required, if `data-bucket` is specified)

### Example
```yaml
- uses: actions/checkout@v4
- uses: yandex-cloud/yc-github-loadtesting-ci/test-run-single@main
  with:
    folder-id: ${{ vars.YC_FOLDER_ID }}
    auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
    test-directory: _impl/testdata/https-const-rps
```

## Action: `test-single-check`
```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/test-single-check@main
```

Assess results measured in a single test run.

The assessment is performed via custom scripts (`check_summary.sh` and `check_report.sh`) which can be added to test directory:
```sh
TEST_ID="bb4asdfjljbhh" # some test id
TEST_DIR="_impl/testdata/http-const-rps" # test-directory

yc --format json loadtesting test get $TEST_ID > summary.json
yc --format json loadtesting test get-report-tables $TEST_ID > report.json

set -e
$DIR/check_summary.sh summary.json
$DIR/check_report.sh report.json
```

If `check_report.sh` or `check_summary.sh` are not found in test directory, some basic checks will be performed instead.

<!--doc-begin-test-single-check-->
### Inputs
|Input|Description|Default|Required|
|-----|-----------|-------|:------:|
|`folder-id`|ID of a folder in Yandex Cloud.|n/a|yes|
|`auth-key-json-base64`|<p>BASE64 encoded authorized key string in JSON format. This setting is preferred over <code>auth-key-json</code>.</p><p>The action will perform all operations on behalf of a service account for which this authorized key was generated.</p><p>Given a json file, encode it via command line <code>base64 &lt;authorized_key.json &gt;authorized_key.pem</code> and add the content of result file to GitHub secrets.</p>|n/a|no|
|`auth-key-json`|<p>Use 'auth-key-json-base64'.</p><p>An authorized key string in JSON format.</p><p>The use of this parameter is discouraged because it can lead to unwanted logs obfuscation (see <a href="https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets">naming your secrets</a>).</p>|``|no|
|`action-log-level`|Action log level.|`NOTICE`|no|
|`test-id`|ID of a test to be checked.|n/a|yes|
|`test-directory`|Directory with test configuration files.|n/a|yes|
### Outputs
|Output|Description|
|------|-----------|
|`raw-output`|Raw stdout of a check script.|
|`report-file`|Path to generated .md report file.|
|`artifacts-dir`|Action artifacts directory. If needed, save it using actions/upload_artifacts.|
<!--doc-end-test-single-check-->

### Required roles
- `loadtesting.loadTester` - to retrieve information about the test

### Example
```yaml
- uses: actions/checkout@v4
- uses: yandex-cloud/yc-github-loadtesting-ci/test-run-single@main
  id: run-test
  with:
    folder-id: ${{ vars.YC_FOLDER_ID }}
    auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
    test-directory: _impl/testdata/https-const-rps
- uses: yandex-cloud/yc-github-loadtesting-ci/test-check-single@main
  with:
    folder-id: ${{ vars.YC_FOLDER_ID }}
    auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}
    test-id: ${{ steps.run-test.outputs.test-id }}
    test-directory: _impl/testdata/https-const-rps
```
