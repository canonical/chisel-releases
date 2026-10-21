from pluggy import HookimplMarker, HookspecMarker, PluginManager


hookspec = HookspecMarker("demo")
hookimpl = HookimplMarker("demo")


class Spec:
    @hookspec(firstresult=True)
    def choose(self, value):
        pass


class Plugin:
    @hookimpl
    def choose(self, value):
        return value * 2


manager = PluginManager("demo")
manager.add_hookspecs(Spec)
plugin = Plugin()
assert manager.register(plugin, name="double") == "double"
assert manager.hook.choose(value=21) == 42
assert manager.get_plugin("double") is plugin
assert manager.unregister(name="double") is plugin

print("success")
