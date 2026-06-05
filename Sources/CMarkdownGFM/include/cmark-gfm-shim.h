#ifndef OPENMARKED_CMARK_GFM_SHIM_H
#define OPENMARKED_CMARK_GFM_SHIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CMARK_OPT_DEFAULT 0
#define CMARK_OPT_SOURCEPOS (1 << 1)
#define CMARK_OPT_HARDBREAKS (1 << 2)
#define CMARK_OPT_SAFE (1 << 3)
#define CMARK_OPT_NOBREAKS (1 << 4)
#define CMARK_OPT_VALIDATE_UTF8 (1 << 9)
#define CMARK_OPT_SMART (1 << 10)
#define CMARK_OPT_GITHUB_PRE_LANG (1 << 11)
#define CMARK_OPT_LIBERAL_HTML_TAG (1 << 12)
#define CMARK_OPT_FOOTNOTES (1 << 13)
#define CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE (1 << 14)
#define CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES (1 << 15)
#define CMARK_OPT_FULL_INFO_STRING (1 << 16)
#define CMARK_OPT_UNSAFE (1 << 17)

typedef struct cmark_node cmark_node;
typedef struct cmark_parser cmark_parser;
typedef struct cmark_syntax_extension cmark_syntax_extension;
typedef struct _cmark_llist cmark_llist;

cmark_parser *cmark_parser_new(int options);
void cmark_parser_free(cmark_parser *parser);
void cmark_parser_feed(cmark_parser *parser, const char *buffer, size_t len);
cmark_node *cmark_parser_finish(cmark_parser *parser);
void cmark_node_free(cmark_node *node);
char *cmark_render_html(cmark_node *root, int options, cmark_llist *extensions);
cmark_llist *cmark_parser_get_syntax_extensions(cmark_parser *parser);
cmark_syntax_extension *cmark_find_syntax_extension(const char *name);
int cmark_parser_attach_syntax_extension(cmark_parser *parser, cmark_syntax_extension *extension);
void cmark_gfm_core_extensions_ensure_registered(void);
const char *cmark_version_string(void);

#ifdef __cplusplus
}
#endif

#endif

