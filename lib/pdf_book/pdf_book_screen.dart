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
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:otzaria/utils/page_converter.dart';
import 'package:otzaria/widgets/password_dialog.dart';
import 'pdf_outlines_screen.dart';
import 'pdf_search_screen.dart';
import 'pdf_thumbnails_screen.dart';

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
            widget.tab.outline.value,
          );
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
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
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'חיפוש וניווט',
              onPressed: () {
                widget.tab.showLeftPane.value = !widget.tab.showLeftPane.value;
              },
            ),
            actions: [
              _buildTextButton(
                context,
                widget.tab.book,
                widget.tab.outline.value ?? [],
                widget.tab.pdfViewerController,
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                tooltip: 'הוספת סימניה',
                onPressed: () {
                  int index = widget.tab.pdfViewerController.isReady
                      ? widget.tab.pdfViewerController.pageNumber!
                      : 1;
                  bool bookmarkAdded = Provider.of<BookmarkBloc>(context, listen: false)
                      .addBookmark(
                        ref: '${widget.tab.title} עמוד $index',
                        book: widget.tab.book,
                        pageNumber: index,
                      );
                  if (bookmarkAdded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('הסימניה נוספה בהצלחה')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('הסימניה קיימת כבר')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'הדפסה',
                onPressed: () async {
                  final file = File(widget.tab.book.path);
                  await Printing.layoutPdf(
                    onLayout: (format) => file.readAsBytes(),
                  );
                },
              ),
            ],
          ),
          body: Row(
            children: [
              if (wideScreen && widget.tab.showLeftPane.value) ...[
                SizedBox(
                  width: 300,
                  child: _LeftPane(
                    tab: widget.tab,
                    textSearcher: textSearcher,
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Stack(
                  children: [
                    PdfViewer(
                      controller: widget.tab.pdfViewerController,
                      source: PdfSource.file(File(widget.tab.book.path)),
                      params: const PdfViewerParams(
                        layoutPages: true,
                        backgroundColor: Colors.white,
                        minScale: 1.0,
                        maxScale: 5.0,
                      ),
                      onDocumentLoadFailed: (error) {
                        if (error.type == PdfErrorType.passwordRequired) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return PasswordDialog(
                                onSubmitted: (password) {
                                  widget.tab.pdfViewerController.setPassword(password);
                                },
                              );
                            },
                          );
                        }
                      },
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: PageNumberDisplay(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextButton(BuildContext context, Book book, List<PdfOutlineNode> outline, PdfViewerController controller) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: const Text('חיפוש'),
        ),
        PopupMenuItem(
          value: 1,
          child: const Text('תוכן עניינים'),
        ),
        PopupMenuItem(
          value: 2,
          child: const Text('תמונות ממוזערות'),
        ),
        PopupMenuItem(
          value: 3,
          child: const Text('פתיחה בקורא אחר'),
        ),
      ],
      onSelected: (value) async {
        if (value == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfSearchScreen(
                tab: widget.tab,
                textSearcher: textSearcher,
              ),
            ),
          );
        } else if (value == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfOutlinesScreen(
                tab: widget.tab,
                outline: outline,
                controller: controller,
              ),
            ),
          );
        } else if (value == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfThumbnailsScreen(
                controller: controller,
              ),
            ),
          );
        } else if (value == 3) {
          if (await canLaunchUrl(Uri.file(book.path))) {
            await launchUrl(Uri.file(book.path));
          }
        }
      },
    );
  }
}

class _LeftPane extends StatelessWidget {
  final PdfBookTab tab;
  final PdfTextSearcher textSearcher;

  const _LeftPane({
    Key? key,
    required this.tab,
    required this.textSearcher,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: tab.leftPaneIndex,
      builder: (context, index, child) {
        if (index == 0) {
          return PdfSearchScreen(tab: tab, textSearcher: textSearcher);
        } else if (index == 1) {
          return PdfOutlinesScreen(
            tab: tab,
            outline: tab.outline.value ?? [],
            controller: tab.pdfViewerController,
          );
        } else if (index == 2) {
          return PdfThumbnailsScreen(controller: tab.pdfViewerController);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
