using System;
using System.Net;

// Small helper class providing CIDR parsing and utility functions used by
// the PowerShell scripts. Implemented in C# for performance and precise
// bitwise operations on IPv4 addresses.
public class IpNetwork
{
    public IPAddress NetworkAddress { get; private set; }
    public IPAddress Netmask { get; private set; }
    public IPAddress BroadcastAddress { get; private set; }
    public int Cidr { get; private set; }

    private uint networkInt;
    private uint maskInt;
    private uint broadcastInt;

    // Construct from a CIDR string like "192.0.2.0/24"
    public IpNetwork(string cidr)
    {
        // Expects "x.x.x.x/n"
        var parts = cidr.Split('/');
        if (parts.Length != 2) throw new ArgumentException("Invalid CIDR.");

        IPAddress ip;
        if (!IPAddress.TryParse(parts[0], out ip))
            throw new ArgumentException("Invalid IP in CIDR.");

        int prefix;
        if (!int.TryParse(parts[1], out prefix))
            throw new ArgumentException("Invalid prefix.");

        if (ip.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
            throw new NotSupportedException("IPv6 not supported in this sample.");

        if (prefix < 0 || prefix > 32)
            throw new ArgumentException("Prefix out of range.");

        this.Cidr = prefix;
        this.maskInt = prefix == 0 ? 0 : (uint)(0xFFFFFFFF << (32 - prefix));
        this.networkInt = ToUInt32(ip) & maskInt;
        this.broadcastInt = networkInt | ~maskInt;

        this.NetworkAddress = FromUInt32(networkInt);
        this.Netmask = FromUInt32(maskInt);
        this.BroadcastAddress = FromUInt32(broadcastInt);
    }

    // Check if the given IPv4 address is contained within this network
    public bool Contains(IPAddress ip)
    {
        if (ip.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork) return false;
        var ipInt = ToUInt32(ip);
        return ipInt >= networkInt && ipInt <= broadcastInt;
    }

    // Safe TryParse helper to avoid exceptions bubbling into PowerShell
    public static bool TryParse(string cidr, out IpNetwork net)
    {
        try
        {
            net = new IpNetwork(cidr);
            return true;
        }
        catch
        {
            net = null;
            return false;
        }
    }

    // Convert IPAddress to 32-bit unsigned integer for easy arithmetic
    public static uint ToUInt32(IPAddress ip)
    {
        var bytes = ip.GetAddressBytes();
        if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
        return BitConverter.ToUInt32(bytes, 0);
    }

    // Convert 32-bit unsigned integer back to IPAddress
    public static IPAddress FromUInt32(uint value)
    {
        var bytes = BitConverter.GetBytes(value);
        if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
        return new IPAddress(bytes);
    }
}