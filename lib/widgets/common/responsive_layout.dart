import 'package:material_ui/material_ui.dart';

/// Helper và Wrapper hỗ trợ Responsive Layout cho Mobile, Tablet và Web.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static const double mobileBreakpoint = 650;
  static const double tabletBreakpoint = 1050;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= tabletBreakpoint && desktop != null) {
      return desktop!;
    }

    if (width >= mobileBreakpoint && tablet != null) {
      return tablet!;
    }

    return mobile;
  }
}

/// Container giới hạn chiều rộng tối đa và căn giữa cho màn hình lớn (Tablet, Web).
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1050,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= ResponsiveLayout.mobileBreakpoint;
    final defaultPadding = EdgeInsets.symmetric(
      horizontal: isWide ? 28.0 : 16.0,
      vertical: isWide ? 20.0 : 14.0,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}
