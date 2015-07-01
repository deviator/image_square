module grid;

import std.random;

import des.math.linear;

import std.stdio;
import std.string;
import std.algorithm;
import std.range;

class Rect
{
    ivec2 pos;
    ivec2 size;

    this() {}

    this( ivec2 pos, ivec2 size )
    {
        this.pos = pos;
        this.size = size;
    }

    int area() const { return size.x * size.y; }

    ivec2 lim() const { return pos + size; }
    void setLim( ivec2 l ) { size = l - pos; }
}

class Grid
{
protected:

    ivec2 _size;

    Rect[] elems;

    ivec2 min_elem;
    ivec2 max_elem;

public:

    invariant
    {
        assert( min_elem.x > 0, "min_elem.x must be > 0" );
        assert( min_elem.y > 0, "min_elem.y must be > 0" );
        assert( max_elem.x >= min_elem.x, "max_elem.x must be >= min_elem.x" );
        assert( max_elem.y >= min_elem.y, "max_elem.y must be >= min_elem.y" );
    }

    this( ivec2 max_elem, ivec2 min_elem=ivec2(1) )
    {
        this.min_elem = min_elem;
        this.max_elem = max_elem;
    }

    void update( ivec2 size, size_t count )
    {
        elems = iota(count).map!(a=>new Rect).array;

        _size = size;

        if( count > 0 )
        {
            replace();
            correct();
        }
    }

    const @property
    {
        ref const(ivec2) size() { return _size; }
        const(Rect)[] elements() { return elems; }

        int width() { return _size.x; }
        int height() { return _size.y; }
    }

protected:

    Rect[] places;

    void replace()
    {
        places = [];
        foreach( i, e; elems )
        {
            bool place_finded = false;
            
            while( !place_finded )
            {
                if( !place_finded )
                    place_finded = findHole( e );

                if( !place_finded )
                {
                    if( i != elems.length - 1 )
                        foreach( try_n; 0 .. 3 )
                        {
                            e.size = randomSize();
                            place_finded = findPlace( e );
                            if( place_finded ) break;
                        }
                    else place_finded = findHole( e, true );
                }

                if( !place_finded )
                {
                    places.length += width * max_elem.y;
                    place_finded = findPlace( e );
                    if( place_finded ) break;
                }
            }

            setPlace( e );
        }
    }

    ivec2 randomSize() const
    {
        return ivec2( uniform!"[]"( min_elem.x, max_elem.x ),
                      uniform!"[]"( min_elem.y, max_elem.y ) );
    }

    bool findPlace( Rect e )
    {
        auto lines = places.length / width;
        if( lines < e.size.y ) return false;

        foreach( y; 0 .. lines )
            foreach( x; 0 .. width )
            {
                bool empty = true;

                cc: foreach( yy; 0 .. e.size.y )
                    foreach( xx; 0 .. e.size.x )
                    {
                        if( yy+y >= lines ||
                            xx+x >= width || 
                            places[(y+yy)*width + (x+xx)] )
                        {
                            empty = false;
                            break cc;
                        }
                    }

                if( empty )
                {
                    e.pos.x = cast(int)x;
                    e.pos.y = cast(int)y;
                    return true;
                }
            }

        return false;
    }

    bool findHole( Rect e, bool use_bottom_edge=false )
    {
        auto lines = places.length / width;
        if( lines < 3 && !use_bottom_edge ) return false;

        foreach( y; 0 .. lines )
            foreach( x; 0 .. width )
            {
                if( places[y*width + x] ) continue;

                bool get_hole = false;

                auto sz_x = 0, sz_y = 0;

                foreach( ex; x .. width )
                    if( places[y*width + ex] || sz_x >= max_elem.x ) break;
                    else sz_x++;

                cc: foreach( yy; y .. lines )
                {
                    foreach( xx; 0 .. sz_x )
                    {
                        if( places[yy*width + (x+xx)] )
                        {
                            get_hole = true;
                            break cc;
                        }
                    }
                    sz_y++;
                    if( sz_y >= max_elem.y || yy == lines-1 )
                    {
                        get_hole = use_bottom_edge;
                        break cc;
                    }
                }

                if( get_hole )
                {
                    e.size.x = sz_x;
                    e.size.y = sz_y;
                    e.pos.x = cast(int)x;
                    e.pos.y = cast(int)y;
                    return true;
                }
            }

        return false;
    }

    debug void printPlaces( string msg, Rect e, bool select=false )
    {
        auto lines = places.length / width;

        writefln( "grid: %s, %s, %s%s", [width,lines], msg, e.pos, e.size );

        void printLine()
        {
            foreach( x; 0 .. width+2 )
                write("-");
            writeln();
        }

        auto lim = e.pos + e.size;

        char fillChar( ivec2 p )
        {
            if( !select )
            {
                if( places[p.y*width+p.x] ) return '+';
                else return ' ';
            }
            else
            {
                if( e.pos.x <= p.x && p.x < lim.x &&
                    e.pos.y <= p.y && p.y < lim.y )
                {
                    if( places[p.y*width+p.x] ) return 'x';
                    else return 'o';
                }
                else
                {
                    if( places[p.y*width+p.x] ) return '+';
                    else return ' ';
                }
            }
        }

        printLine();

        foreach( y; 0 .. lines )
        {
            write("|");
            foreach( x; 0 .. width )
                write( fillChar(ivec2(x,y)) );
            writeln("|");
        }

        printLine();
        writeln();
    }

    void setPlace( Rect e, bool engaged=true )
    {
        debug writefln( "set place [%dx%d] at [%dx%d]", e.size.x, e.size.y, e.pos.x, e.pos.y );
        foreach( y; 0 .. e.size.y )
            foreach( x; 0 .. e.size.x )
                places[(e.pos.y+y)*width+(e.pos.x+x)] = engaged ? e : null;
        debug printPlaces( "set place", e, true );
    }

    abstract void correct();
}

class GridWidth : Grid
{
    this( ivec2 max_elem, ivec2 min_elem=ivec2(1) )
    { super( max_elem, min_elem ); }

protected:

    override void correct()
    {
        minimizeFreeSpace();
        zipPlace();
        capHoles();
    }

    void minimizeFreeSpace()
    {
        expandWidth();
        expandHeight();
        crampHeight();
    }

    void expandWidth()
    {
        foreach( e; elems )
        {
            auto fs = cast(int)getFreeSpaceRight(e);
            if( fs == 0 ) continue;

            auto nx = min( fs + e.size.x, max_elem.x );
            if( nx != e.size.x )
            {
                e.size.x = nx;
                setPlace( e );
            }
        }
    }

    void crampHeight()
    {
        auto bottom_edge = cast(int)calcBottomEdgeMin;

        foreach( e; elems )
        {
            auto ny = bottom_edge - e.pos.y;
            if( min_elem.y <= ny && ny < e.size.y )
            {
                setPlace( e, false );
                e.size.y = ny;
                setPlace( e );
            }
        }
    }

    void expandHeight()
    {
        auto bottom_edge = cast(int)calcBottomEdgeMax;

        writeln( "expand height" );
        foreach( e; elems )
        {
            auto fs = cast(int)getFreeSpaceBelow(e);
            writeln( "fs: ", fs );
            if( fs == 0 ) continue;

            auto edge_lim = bottom_edge - e.pos.y;
            writeln( "edge_lim: ", edge_lim );
            if( edge_lim <= 0 ) continue;

            auto ny = reduce!min( [ fs + e.size.y, max_elem.y, edge_lim ] );
            if( ny != e.size.y )
            {
                e.size.y = ny;
                setPlace( e );
            }
        }
    }

    size_t calcBottomEdgeMax()
    {
        size_t edge = 0;

        auto lines = places.length / width;

        foreach( x; 0 .. width )
            foreach( y; 0 .. lines )
                if( places[y*width+x] && y > edge )
                    edge = y;

        return edge + 1;
    }

    size_t calcBottomEdgeMin()
    {
        size_t edge = calcBottomEdgeMax();

        auto lines = places.length / width;

        foreach( e; elems )
        {
            auto e_edge = e.lim.y;
            if( getFreeSpaceBelow(e) || e_edge == lines )
                if( e_edge < edge )
                    edge = e_edge;
        }

        foreach( e; elems )
        {
            if( e.pos.y + min_elem.y > edge )
                edge = e.pos.y + min_elem.y;
        }

        return edge;
    }

    size_t getFreeSpaceBelow( Rect e )
    {
        auto lines = places.length / width;

        size_t ret = 0;
        foreach( y; e.lim.y .. lines )
        {
            foreach( x; 0 .. e.size.x )
                if( places[y*width+e.pos.x+x] ) return ret;
            ret++;
        }
        return ret;
    }

    size_t getFreeSpaceRight( Rect e )
    {
        size_t ret = 0;
        foreach( x; e.lim.x .. width )
        {
            foreach( y; e.pos.y .. e.lim.y )
                if( places[y*width + x] ) return ret;
            ret++;
        }
        return ret;
    }

    void zipPlace()
    {
        auto height = calcBottomEdgeMax;
        places = new Rect[]( width * height );
        foreach( e; elems ) setPlace( e );
    }

    void capHoles()
    {
        auto tmp = new Rect;
        while( findHole( tmp, true ) )
        {
            writeln( "hole: ", tmp.pos, tmp.size );
            auto pair = findMergeable();

            if( pair[0] is null ||
                pair[1] is null ) break;

            setPlace( pair[0], false );
            setPlace( pair[1], false );

            mergeElems( pair[0], pair[1] );

            pair[1].pos = tmp.pos;
            pair[1].size = tmp.size;

            setPlace( pair[0] );
            setPlace( pair[1] );
        }
    }

    Rect[2] findMergeable()
    {
        foreach( e; elems.randomSample(elems.length) )
        {
            if( auto r = getRightMergeable(e) ) return [e,r];
            if( auto b = getBottomMergeable(e) ) return [e,b];
        }
        return [null,null];
    }

    Rect getRightMergeable( Rect e )
    {
        if( e.lim.x < width-1 )
        {
            auto right = places[e.pos.y*width + e.lim.x];
            if( right !is null &&
                right.pos.y == e.pos.y &&
                right.size.y == e.size.y &&
                right.size.x + e.size.x < max_elem.x )
                return right;
        }
        return null;
    }

    Rect getBottomMergeable( Rect e )
    {
        auto lines = places.length / width;
        if( e.lim.y < lines-1 )
        {
            auto bottom = places[e.lim.y*width + e.pos.x];
            if( bottom !is null &&
                bottom.pos.x == e.pos.x &&
                bottom.size.x == e.size.x &&
                bottom.size.y + e.size.y < max_elem.y )
                return bottom;
        }
        return null;
    }

    void mergeElems( Rect master, Rect slave )
    {
        master.setLim( ivec2( max( master.lim.x, slave.lim.x ),
                              max( master.lim.y, slave.lim.y ) ) );
        master.pos = ivec2( min( master.pos.x, slave.pos.x ),
                            min( master.pos.y, slave.pos.y ) );
    }
}
