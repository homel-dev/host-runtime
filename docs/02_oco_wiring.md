# OCO Wiring

## Consumer-side contract

`host-runtime` publishes two labeled ConfigMaps:

```text
grafana_datasource=1
grafana_dashboard=1
```

and grants the OCO ServiceAccount namespaced read access through:

```text
Role/observability-console-reader
RoleBinding/observability-console-reader
```

## OCO-side watched namespace

The current OCO deployment uses sidecars with a watched namespace set. Add `host-runtime` to the `NAMESPACE` value for both datasource and dashboard sidecars.

Patch file included:

```text
oco-patches/observability-console-watch-host-runtime.patch
```

Expected OCO sidecar namespace value after patch:

```text
llm-runtime,host-runtime
```

## Apply order

```bash
# in host-runtime repo
task deploy

# in oco repo
git apply /path/to/host-runtime/oco-patches/observability-console-watch-host-runtime.patch
task oco:deploy
task oco:restart
```
