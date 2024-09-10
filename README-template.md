# GitHub Actions for Yandex Cloud Load Testig service

## Summary

List of available actions:
* _agents-create_ - create and start load testing agents using Yandex Cloud Compute VMs for hosting (Compute is billed separately)
* _agents-delete_ - delete load testing agents
* _test-suite_ - execute multiple load tests sequentially
* _test-single-run_ - execute a single load test
* _test-single-check_ - check results of a single load test

## test-sute

<!--doc-begin-test-suite-->
<!--doc-end-test-suite-->

### Required roles
todo

### Example
todo

## agents-create

Create agents alongside with Cloud Compute VMs to host them.
  
This action is usually used used in pair with 'agents-delete' action.

<!--doc-begin-agents-create-->
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
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Agent service account ID (with role 'loadtesting.generatorClient').
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}

  # Agent labels.
  labels: "workflow=${{ github.run_id }}"

  # Number of agents to be created.
  # count: 1

  # Compute zone to run agent VM in.
  # vm-zone: ru-central1-a
```

<details><summary>Custom CPU and RAM settings:</summary>

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Agent service account ID (with role 'loadtesting.generatorClient').
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}

  # Agent labels.
  labels: "workflow=${{ github.run_id }}"

  # Number of agents to be created.
  # count: 1

  # Compute zone to run agent VM in.
  # vm-zone: ru-central1-a

  # Additional cli arguments.
  cli-args: |-
    --cores 2
    --memory 2G
```

</details>

<details><summary>Custom network settings:</summary>

This version is essentially identical to `yc loadtesting agent create ${cli-args}`.

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Number of agents to be created.
  # count: 1

  # Additional cli arguments.
  cli-args: |-
    --service-account-id "${{ vars.YC_LOADTESTING_SA_ID }}"
    --labels "workflow=${{ github.run_id }}"
    --cores 2
    --memory 2G
    --zone 'ru-central1-a'
    --network-settings "subnet-name=default-a,security-group-ids=${{ vars.YC_LOADTESTING_AGENT_SECURITY_GROUP_ID }}"
```

</details>

## agents-delete

Delete agents (and the VMs).

This action is usually used used in pair with 'agents-create' action.

<!--doc-begin-agents-delete-->
<!--doc-end-agents-delete-->

### Required roles
- `loadtesting.loadTester` - to delete an agent
- `compute.editor` - to stop and delete agent VM

### Example

This action is usually used in pair with `create-agent`:

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

## test-single-run

<!--doc-begin-test-single-run-->
<!--doc-end-test-single-run-->

### Required roles
todo

### Example
todo

## test-single-check

<!--doc-begin-test-single-check-->
<!--doc-end-test-single-check-->

### Required roles
todo

### Example
todo
