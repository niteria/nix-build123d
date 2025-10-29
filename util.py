import inspect

def params():
    # Get the caller's frame to access its local variables
    frame = inspect.currentframe().f_back
    locals_dict = frame.f_locals

    # Filter for int and float, excluding bool
    numeric_vars = {
        k: v for k, v in locals_dict.items()
        if (isinstance(v, (int, float)) and not isinstance(v, bool) and k not in {"CM","FT","G","IN","KG","LB","M","MC","MM","dpr","sqr2"})
    }

    if not numeric_vars:
        return ""

    # Format each value appropriately
    def format_value(v):
        if isinstance(v, int):
            return str(v)
        else:  # float
            return f"{v:g}"  # Removes trailing zeros and .0

    # Create parts like "var_name=value", sorted by var_name
    parts = [f"{k}={format_value(v)}" for k, v in sorted(numeric_vars.items())]

    # Join with underscores
    return "_".join(parts)
