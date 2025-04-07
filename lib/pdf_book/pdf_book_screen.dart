import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/pdf_book/pdf_page_number_dispaly.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/utils/open_book.dart';
import 'package:otzaria/utils/ref_helper.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'pdf_search_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_outlines_screen.dart';
import 'package:otzaria/widgets/password_dialog.dart';
import 'pdf_thumbnails_screen.dart';
import 'package:printing/printing.dart';
import 'package:otzaria/utils/page_converter.dart';

class PdfBookScreen extends StatefulWidget {
  final PdfBookTab tab;

  const PdfBookScreen({
    super.key,
    required this.tab,
  });

  @override
  State<PdfBookScreen> createState() => _PdfBookScreenState();
}

class _PdfBookScreenState extends State<PdfBookScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final textSearcher = PdfTextSearcher(widget.tab.pdfViewerController)..addListener(_update);

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.tab.pdfViewerController = PdfViewerController();
    widget.tab.pdfViewerController.addListener(() {
      if (widget.tab.pdfViewerController.isReady) {
        widget.tab.pageNumber = widget.tab.pdfViewerController.pageNumber!;
        () async {
          widget.tab.currentTitle.value = await refFromPageNumber(
              widget.tab.pageNumber = widget.tab.pdfViewerController.pageNumber ?? 1,
              widget.tab.outline.value);
        }();
      }
    });
  }

  @override
  void dispose() {
    textSearcher.removeListener(_update);
    widget.tab.pdfViewerController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (context, constrains) {
      final wideScreen = (MediaQuery.of(context).size.width >= 600);
      return Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder(
              valueListenable: widget.tab.currentTitle,
              builder: (context, value, child) => Center(
                    child: SelectionArea(
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 17),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'חיפוש וניווט',
            onPressed: () {
              widget.tab.showLeftPane.value = !widget.tab.showLeftPane.value;
            },
          ),
          actions: [
            _buildTextButton(context, widget.tab.book,
                widget.tab.outline.value ?? [], widget.tab.pdfViewerController),
            IconButton(
              icon: const Icon(
                Icons.bookmark_add,
              ),
              tooltip: 'הוספת סימניה',
              onPressed: () {
                int index = widget.tab.pdfViewerController.isReady
                    ? widget.tab.pdfViewerController.pageNumber!
                    : 1;
                bool bookmarkAdded =
                    Provider.of<BookmarkBloc>(context, listen: false)
                        .addBookmark(
                            ref: '${widget.tab.title} עמוד $index',
                            book: widget.tab.book,
                        );
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                            child: MouseRegion(
                              onEnter: (_) => setState(() {}),
                              onExit: (_) => setState(() {}),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'ניווט',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Tab(
                            child: MouseRegion(
                              onEnter: (_) => setState(() {}),
                              onExit: (_) => setState(() {}),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'חיפוש',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Tab(
                            child: MouseRegion(
                              onEnter: (_) => setState(() {}),
                              onExit: (_) => setState(() {}),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'דפים',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            Center(child: Text('ניווט תוכן')),
                            Center(child: Text('חיפוש טקסט')),
                            Center(child: Text('תצוגת דפים')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

  Future<void> navigateToUrl(Uri url) async {
    if (await shouldOpenUrl(context, url)) {
      await launchUrl(url);
    }
  }

  Future<bool> shouldOpenUrl(BuildContext context, Uri url) async {
    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('לעבור לURL?'),
          content: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'האם לעבור לכתובת הבאה\n'),
                  TextSpan(
                    text: url.toString(),
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('עבור'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildTextButton(BuildContext context, PdfBook book,
      List<PdfOutlineNode> outline, PdfViewerController controller) {
    return FutureBuilder(
      future: DataRepository.instance.library
          .then((library) => library.findBookByTitle(book.title, TextBook)),
      builder: (context, snapshot) => snapshot.hasData
          ? IconButton(
              icon: const Icon(Icons.article),
              tooltip: 'פתח טקסט',
              onPressed: () async {
                final index = await pdfToTextPage(
                    book, outline, controller.pageNumber ?? 1, context);
                openBook(context, snapshot.data!, index ?? 0, '');
              })
          : const SizedBox.shrink(),
    );
  }
}
