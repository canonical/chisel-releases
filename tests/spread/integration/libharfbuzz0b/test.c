#include <harfbuzz/hb.h>
#include <stdlib.h>

int main()
{
    const char* text = "Sample text";
    hb_buffer_t *buf;
    buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
    hb_buffer_set_script(buf, HB_SCRIPT_LATIN);
    hb_buffer_set_language(buf, hb_language_from_string("en", -1));
    hb_blob_t *blob = hb_blob_create_from_file("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf");
    if (blob == NULL)
        exit(-1);
    hb_face_t *face = hb_face_create(blob, 0);
    if (face == NULL)
        exit(-2);

    hb_font_t *font = hb_font_create(face);
    if (font == NULL)
        exit(-3);

    hb_shape(font, buf, NULL, 0);
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    if (glyph_count == 0)
        exit(-4);
    if (glyph_info == NULL)
        exit(-5);

    hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
    if (glyph_count == 0)
        exit(-6);
    if (glyph_pos == NULL)
        exit(-7);
}
