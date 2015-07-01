import std.stdio;

import des.log;
import des.math.linear;

import gtk.MainWindow;
import gtk.DrawingArea;
import gtk.Widget;
import gtk.Main;
import cairo.Context;
import cairo.Surface;
import cairo.ImageSurface;

import std.algorithm;
import std.array;
import std.range;
import std.random;

import grid;

class ImageCell
{
    ImageLayout parent;
    vec3 color;
    ivec2 pos;
    ivec2 cells;

    this( ImageLayout layout )
    {
        this.parent = layout;
        color = vec3( uniform(.3,1), uniform(.3,1), uniform(.3,1) );
    }

    @property
    {
        ivec2 realPos() { return (parent.cell_size + parent.gap_size) * pos; }
        ivec2 realSize() { return (parent.cell_size + parent.gap_size) * cells - parent.gap_size; }
    }
}

class ImageLayout
{
    ImageCell[] images;

    ivec2 cell_size;
    ivec2 gap_size;

    Grid grid;

    this( ivec2 cell, ivec2 gap )
    {
        this.cell_size = cell;
        this.gap_size = gap;
        this.grid = new GridWidth( ivec2(4,5), ivec2(1) );
    }

    void setCount( size_t count )
    {
        images = iota(count).map!(a=>new ImageCell(this)).array;
    }

    void recalc( ivec2 size )
    {
        if( size.x < cell_size.x ) return;
        if( size.y < cell_size.y ) return;

        auto g_size = size / ( cell_size + gap_size );

        if( this.grid.size.x == g_size.x ) return;

        this.grid.update( g_size, images.length );

        foreach( ref pack; zip( this.grid.elements, images.randomSample(images.length) ) )
        {
            pack[1].pos = pack[0].pos;
            pack[1].cells = pack[0].size;
        }
    }
}

final class UI : MainWindow
{
    ImageLayout layout;

    this()
    {
        super( "test image squre algo" );
        setBorderWidth(5);

        auto dr = new DrawingArea;
        
        add( dr );

        addOnHide( (Widget aux){ Main.quit(); } );

        layout = new ImageLayout( ivec2(20), ivec2(4) );

        layout.setCount( 140 );

        showAll();

        updateLayout();

        dr.addOnDraw( (Scoped!Context cr, Widget aux)
        {
            cr.setSourceRgb( 0, 0, 0 );
            cr.rectangle( 0, 0, aux.getAllocatedWidth(), aux.getAllocatedHeight() );
            cr.fill();
            
            foreach( img; layout.images )
            {
                cr.save();
                cr.setSourceRgb( img.color.r, img.color.g, img.color.b );

                cr.rectangle( img.realPos.x, img.realPos.y,
                              img.realSize.x, img.realSize.y );
                cr.fill();
                cr.restore();
            }
            return true;
        });

        addOnKeyPress( ( GdkEventKey* key, Widget aux )
        {
            if( key.keyval == 32 ) updateLayout();
            return true;
        });

        addOnCheckResize((aux) { layout.recalc( getSize() ); });
    }

    void updateLayout()
    {
        if( layout ) layout.recalc( getSize() );
        queueDraw();
    }

    ivec2 getSize() { return ivec2( getAllocatedWidth(), getAllocatedHeight() ); }
}

void main( string[] args )
{
    Main.init( args );
    new UI;
    Main.run();
}
