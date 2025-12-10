using System;
using System.Net;

public class IpNetwork
{
    public IPAddress NetworkAddress { get; private set; }
    public IPAddress Netmask { get; private set; }
    public int Cidr { get; private set; }
    private uint networkInt;
    private uint maskInt;

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
        this.NetworkAddress = FromUInt32(networkInt);
        this.Netmask = FromUInt32(maskInt);
    }

    public bool Contains(IPAddress ip)
    {
        if (ip.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork) return false;
        var ipInt = ToUInt32(ip);
        return (ipInt & maskInt) == networkInt;
    }

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

    public static uint ToUInt32(IPAddress ip)
    {
        var bytes = ip.GetAddressBytes();
        if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
        return BitConverter.ToUInt32(bytes, 0);
    }

    public static IPAddress FromUInt32(uint value)
    {
        var bytes = BitConverter.GetBytes(value);
        if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
        return new IPAddress(bytes);
    }
}