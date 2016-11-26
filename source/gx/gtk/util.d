/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.util;

import std.conv;
import std.experimental.logger;
import std.format;
import std.process;
import std.string;

import gdk.Atom;
import gdk.Gdk;
import gdk.RGBA;
import gdk.X11;

import gio.ListModelIF;
import gio.Settings: GSettings = Settings;

import glib.GException;
import glib.ListG;

import gobject.ObjectG;
import gobject.Value;

import gtk.Bin;
import gtk.Box;
import gtk.ComboBox;
import gtk.CellRendererText;
import gtk.Container;
import gtk.Entry;
import gtk.ListStore;
import gtk.Paned;
import gtk.Settings;
import gtk.StyleContext;
import gtk.TreeIter;
import gtk.TreeModelIF;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;

import gx.gtk.x11;

/**
 * Activates a window using the X11 APIs when available
 */
void activateWindow(Window window) {
    if (window.isActive()) return;

    if (isWayland(window)) {
        window.present();
    } else {
        activateX11Window(window);
    }
}

/**
 * Returns true if running under Wayland, right now
 * it just uses a simple environment variable check to detect it.
 */
bool isWayland(Window window) {
    try {
        environment["WAYLAND_DISPLAY"];
        return true;
    } catch (Exception e) {
        return false;
    }
}

/**
 * Return the name of the GTK Theme
 */
string getGtkTheme() {
    Value value = new Value("");
    Settings.getDefault.getProperty("gtk-theme-name", value);
    return value.getString();
}

/**
 * Convenience method for creating a box and adding children
 */
Box createBox(Orientation orientation, int spacing,  Widget[] children) {
    Box result = new Box(orientation, spacing);
    foreach(child; children) {
        result.add(child);
    }
    return result;
}

/**
 * Finds the index position of a child in a container.
 */
int getChildIndex(Container container, Widget child) {
    Widget[] children = container.getChildren().toArray!Widget();
    foreach(int i, c; children) {
        if (c.getWidgetStruct() == child.getWidgetStruct()) return i;
    }
    return -1;
}

/**
 * Template for finding all children of a specific type
 */
T[] getChildren(T) (Widget widget, bool recursive) {
    T[] result;
    Widget[] children;
    Bin bin = cast(Bin) widget;
    if (bin !is null) {
        children = [bin.getChild()];
    }
    Container container = cast(Container) widget;
    if (container !is null) {
        ListG list = container.getChildren();
        if (list !is null)
            children = list.toArray!(Widget)();
    }

    foreach(child; children) {
        T match = cast(T) child;
        if (match !is null) result ~= match;
        if (recursive) {
            result ~= getChildren!(T)(child, recursive);
        }
    }
    return result;
}

/**
 * Gets the background color from style context. Works around
 * spurious VTE State messages on GTK 3.19 or later. See the
 * blog entry here: https://blogs.gnome.org/mclasen/2015/11/20/a-gtk-update/
 */
void getStyleBackgroundColor(StyleContext context, StateFlags flags, out RGBA color) {
    with (context) {
        save();
        setState(flags);
        getBackgroundColor(getState(), color);
        restore();
    }
}

/**
 * Gets the color from style context. Works around
 * spurious VTE State messages on GTK 3.19 or later. See the
 * blog entry here: https://blogs.gnome.org/mclasen/2015/11/20/a-gtk-update/
 */
void getStyleColor(StyleContext context, StateFlags flags, out RGBA color) {
    with (context) {
        save();
        setState(flags);
        getColor(getState(), color);
        restore();
    }
}

/**
 * Sets all margins of a widget to the same value
 */
void setAllMargins(Widget widget, int margin) {
    setMargins(widget, margin, margin, margin, margin);
}

/**
 * Sets margins of a widget to the passed values
 */
void setMargins(Widget widget, int left, int top, int right, int bottom) {
    widget.setMarginLeft(left);
    widget.setMarginTop(top);
    widget.setMarginRight(right);
    widget.setMarginBottom(bottom);
}

/**
 * Defined here since not defined in GtkD
 */
enum MouseButton : uint {
    PRIMARY = 1,
    MIDDLE = 2,
    SECONDARY = 3
}

/**
 * Compares two RGBA and returns if they are equal, supports null references
 */
bool equal(RGBA r1, RGBA r2) {
    if (r1 is null && r2 is null)
        return true;
    if ((r1 is null && r2 !is null) || (r1 !is null && r2 is null))
        return false;
    return r1.equal(r2);
}

bool equal(Widget w1, Widget w2) {
    if (w1 is null && w2 is null)
        return true;
    if ((w1 is null && w2 !is null) || (w1 !is null && w2 is null))
        return false;
    return w1.getWidgetStruct() == w2.getWidgetStruct();
}

/**
 * Converts an RGBA structure to a 8 bit HEX string, i.e #2E3436
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo8bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X", red, green, blue, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X", red, green, blue);
    }
}

/**
 * Converts an RGBA structure to a 16 bit HEX string, i.e #2E2E34343636
 * Right now this just takes an 8 bit string and repeats each channel
 *
 * Params:
 * RGBA	 = The color to convert
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a #
 */
string rgbaTo16bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
    string prepend = includeHash ? "#" : "";
    int red = to!(int)(color.red() * 255);
    int green = to!(int)(color.green() * 255);
    int blue = to!(int)(color.blue() * 255);
    if (includeAlpha) {
        int alpha = to!(int)(color.alpha() * 255);
        return prepend ~ format("%02X%02X%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue, alpha, alpha);
    } else {
        return prepend ~ format("%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue);
    }
}

/**
 * Appends multiple values to a row in a list store
 */
TreeIter appendValues(TreeStore ts, TreeIter parentIter, string[] values) {
    TreeIter iter = ts.createIter(parentIter);
    for (int i = 0; i < values.length; i++) {
        ts.setValue(iter, i, values[i]);
    }
    return iter;
}

/**
 * Appends multiple values to a row in a list store
 */
TreeIter appendValues(ListStore ls, string[] values) {
    TreeIter iter = ls.createIter();
    for (int i = 0; i < values.length; i++) {
        ls.setValue(iter, i, values[i]);
    }
    return iter;
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[string] keyValues) {

    ListStore ls = new ListStore([GType.STRING, GType.STRING]);

    foreach (key, value; keyValues) {
        appendValues(ls, [value, key]);
    }

    ComboBox cb = new ComboBox(ls, false);
    cb.setFocusOnClick(false);
    cb.setIdColumn(1);
    CellRendererText cell = new CellRendererText();
    cell.setAlignment(0, 0);
    cb.packStart(cell, false);
    cb.addAttribute(cell, "text", 0);

    return cb;
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed. Additionally the combobox is
 * bound to a GSettings.
 */
ComboBox createNameValueCombo(const string[] names, const string[] values, GSettings settings, string key) {
    ComboBox cb = createNameValueCombo(names, values);
    settings.bind(key, cb, "active-id", GSettingsBindFlags.DEFAULT);
    return cb;    
}
/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[] names, const string[] values) {
    assert(names.length == values.length);

    ListStore ls = new ListStore([GType.STRING, GType.STRING]);

    for (int i = 0; i < names.length; i++) {
        appendValues(ls, [names[i], values[i]]);
    }

    ComboBox cb = new ComboBox(ls, false);
    cb.setFocusOnClick(false);
    cb.setIdColumn(1);
    CellRendererText cell = new CellRendererText();
    cell.setAlignment(0, 0);
    cb.packStart(cell, false);
    cb.addAttribute(cell, "text", 0);

    return cb;
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[] names, const int[] values) {
    assert(names.length == values.length);

    ListStore ls = new ListStore([GType.STRING, GType.INT]);

    for (int i = 0; i < names.length; i++) {
        TreeIter iter = ls.createIter();
        ls.setValue(iter, 0, names[i]);
        ls.setValue(iter, 1, values[i]);
    }

    ComboBox cb = new ComboBox(ls, false);
    cb.setFocusOnClick(false);
    cb.setIdColumn(1);
    CellRendererText cell = new CellRendererText();
    cell.setAlignment(0, 0);
    cb.packStart(cell, false);
    cb.addAttribute(cell, "text", 0);

    return cb;
}

/**
 * Selects the specified row in a Treeview
 */
void selectRow(TreeView tv, int row, TreeViewColumn column = null) {
    TreeModelIF model = tv.getModel();
    TreeIter iter;
    model.iterNthChild(iter, null, row);
    if (iter !is null) {
        tv.setCursor(model.getPath(iter), column, false);
    } else {
        tracef("No TreeIter found for row %d", row);
    }
}

/**
 * An implementation of a range that allows using foreach with a TreeModel and TreeIter
 */
struct TreeIterRange {

private:
    TreeModelIF model;
    TreeIter iter;
    bool _empty;

public:
    this(TreeModelIF model) {
        this.model = model;
        _empty = !model.getIterFirst(iter);
    }

    this(TreeModelIF model, TreeIter parent) {
        this.model = model;
        _empty = !model.iterChildren(iter, parent);
        if (_empty) trace("TreeIter has no children");
    }

    @property bool empty() {
        return _empty;
    }

    @property auto front() {
        return iter;
    }

    void popFront() {
        _empty = !model.iterNext(iter);
    }

    /**
     * Based on the example here https://www.sociomantic.com/blog/2010/06/opapply-recipe/#.Vm8mW7grKEI
     */
    int opApply(int delegate(ref TreeIter iter) dg) {
        int result = 0;
        //bool hasNext = model.getIterFirst(iter);
        bool hasNext = !_empty;
        while (hasNext) {
            result = dg(iter);
            if (result) {
                break;
            }
            hasNext = model.iterNext(iter);
        }
        return result;
    }
}