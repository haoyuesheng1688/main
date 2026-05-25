using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Siemens.Engineering;
using Siemens.Engineering.HW;
using Siemens.Engineering.HW.Features;
using Siemens.Engineering.SW;
using Siemens.Engineering.SW.Blocks;

internal static class Program
{
    private static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0)
            {
                Console.WriteLine("Usage: CodexTiaBridge.exe <processes|inspect> [processId]");
                return 1;
            }

            switch (args[0].ToLowerInvariant())
            {
                case "processes":
                    ListProcesses();
                    return 0;
                case "inspect":
                    Inspect(args.Length > 1 ? int.Parse(args[1]) : (int?)null);
                    return 0;
                default:
                    Console.WriteLine("Unknown command: " + args[0]);
                    return 1;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            return 2;
        }
    }

    private static void ListProcesses()
    {
        foreach (var process in TiaPortal.GetProcesses())
        {
            Console.WriteLine(
                "PROCESS|Id={0}|Mode={1}|ProjectPath={2}|ExePath={3}|Sessions={4}",
                process.Id,
                process.Mode,
                process.ProjectPath != null ? process.ProjectPath.FullName : string.Empty,
                process.Path != null ? process.Path.FullName : string.Empty,
                process.AttachedSessions.Count);
        }
    }

    private static void Inspect(int? requestedProcessId)
    {
        var process = ResolveProcess(requestedProcessId);
        Console.WriteLine(
            "ATTACHING|Id={0}|Mode={1}|ProjectPath={2}",
            process.Id,
            process.Mode,
            process.ProjectPath != null ? process.ProjectPath.FullName : string.Empty);

        using (var portal = process.Attach())
        {
            Console.WriteLine("ATTACHED|Projects={0}", portal.Projects.Count);

            foreach (Project project in portal.Projects)
            {
                Console.WriteLine(
                    "PROJECT|Name={0}|Path={1}|Devices={2}",
                    project.Name,
                    project.Path != null ? project.Path.FullName : string.Empty,
                    project.Devices.Count);

                foreach (Device device in project.Devices)
                {
                    Console.WriteLine("DEVICE|Name={0}|Type={1}", device.Name, device.TypeIdentifier);

                    foreach (DeviceItem item in EnumerateDeviceItems(device.DeviceItems))
                    {
                        Console.WriteLine(
                            "DEVICEITEM|Name={0}|Type={1}|Classification={2}",
                            item.Name,
                            item.TypeIdentifier,
                            item.Classification);

                        var softwareContainer = item.GetService<SoftwareContainer>();
                        if (softwareContainer == null || softwareContainer.Software == null)
                        {
                            continue;
                        }

                        var software = softwareContainer.Software;
                        Console.WriteLine(
                            "SOFTWARE|DeviceItem={0}|SoftwareType={1}",
                            item.Name,
                            software.GetType().FullName);

                        var plcSoftware = software as PlcSoftware;
                        if (plcSoftware != null)
                        {
                            Console.WriteLine(
                                "PLC|DeviceItem={0}|Blocks={1}|ExternalSources={2}|TagTables={3}",
                                item.Name,
                                plcSoftware.BlockGroup.Blocks.Count,
                                plcSoftware.ExternalSourceGroup.ExternalSources.Count,
                                plcSoftware.TagTableGroup.TagTables.Count);

                            foreach (PlcBlock block in plcSoftware.BlockGroup.Blocks)
                            {
                                Console.WriteLine(
                                    "PLCBLOCK|Name={0}|ProgrammingLanguage={1}|Number={2}",
                                    block.Name,
                                    block.ProgrammingLanguage,
                                    block.Number);
                            }

                            continue;
                        }

                        if (software.GetType().FullName.IndexOf("Hmi", StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            DumpHmiSoftware(item.Name, software);
                        }
                    }
                }
            }
        }
    }

    private static TiaPortalProcess ResolveProcess(int? requestedProcessId)
    {
        IList<TiaPortalProcess> processes = TiaPortal.GetProcesses();
        if (processes.Count == 0)
        {
            throw new InvalidOperationException("No running TIA Portal process was found.");
        }

        if (requestedProcessId.HasValue)
        {
            var specific = processes.FirstOrDefault(p => p.Id == requestedProcessId.Value);
            if (specific == null)
            {
                throw new InvalidOperationException("Requested TIA Portal process was not found: " + requestedProcessId.Value);
            }

            return specific;
        }

        var withProject = processes.FirstOrDefault(p => p.ProjectPath != null);
        return withProject ?? processes[0];
    }

    private static IEnumerable<DeviceItem> EnumerateDeviceItems(DeviceItemComposition roots)
    {
        foreach (DeviceItem item in roots)
        {
            yield return item;
            foreach (DeviceItem child in EnumerateChildren(item))
            {
                yield return child;
            }
        }
    }

    private static IEnumerable<DeviceItem> EnumerateChildren(DeviceItem parent)
    {
        foreach (DeviceItem child in parent.DeviceItems)
        {
            yield return child;
            foreach (DeviceItem nested in EnumerateChildren(child))
            {
                yield return nested;
            }
        }
    }

    private static void DumpHmiSoftware(string deviceItemName, Software software)
    {
        object tags = TryGetPropertyValue(software, "Tags");
        int tagCount = TryGetCount(tags);

        Console.WriteLine(
            "HMI|DeviceItem={0}|RuntimeType={1}|TagCount={2}",
            deviceItemName,
            software.GetType().FullName,
            tagCount);

        var enumerable = tags as System.Collections.IEnumerable;
        if (enumerable != null)
        {
            foreach (object tag in enumerable)
            {
                object name = TryGetPropertyValue(tag, "Name");
                Console.WriteLine("HMITAG|Name={0}", name ?? string.Empty);
            }
        }
    }

    private static object TryGetPropertyValue(object instance, string propertyName)
    {
        if (instance == null)
        {
            return null;
        }

        var property = instance.GetType().GetProperty(propertyName);
        return property != null ? property.GetValue(instance, null) : null;
    }

    private static int TryGetCount(object instance)
    {
        if (instance == null)
        {
            return -1;
        }

        var property = instance.GetType().GetProperty("Count");
        if (property == null)
        {
            return -1;
        }

        object value = property.GetValue(instance, null);
        if (value is int)
        {
            return (int)value;
        }

        return -1;
    }
}
