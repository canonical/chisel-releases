namespace Lib;

/// <summary>A widget.</summary>
public sealed class Widget : IDisposable, IEquatable<Widget>
{
    /// <inheritdoc/>
    public void Dispose()
    {
    }

    /// <inheritdoc/>
    public bool Equals(Widget? other) => other is not null;

    /// <inheritdoc/>
    public override bool Equals(object? obj) => obj is Widget w && Equals(w);

    /// <inheritdoc/>
    public override int GetHashCode() => 0;

    /// <inheritdoc/>
    public override string ToString() => "widget";
}
