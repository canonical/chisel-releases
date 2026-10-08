#include <expat.h>

int main(void) {
    const char document[] = "<root><child/></root>";
    XML_Parser parser = XML_ParserCreate(NULL);
    if (parser == NULL) {
        return 1;
    }
    int status = XML_Parse(parser, document, sizeof(document) - 1, XML_TRUE);
    XML_ParserFree(parser);
    return status == XML_STATUS_OK ? 0 : 2;
}
