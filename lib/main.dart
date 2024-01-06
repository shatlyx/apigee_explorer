import 'package:apigee_explorer/service/files_service.dart';
import 'package:apigee_explorer/views/proxy_explorer.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  var proxyFolder = FilesService.parseProxyFolder('/Users/monta/Downloads/apigee/first-proxy/apiproxy');
  void _onChangePage(BuildContext context, int index) {
    setState(() {
      _selectedIndex = index;
      Navigator.push(
          context,
          PageRouteBuilder(
              transitionDuration: const Duration(seconds: 1),
              pageBuilder: (_, __, ___) => [
                ProxyExplorer(bottomBar: _buildBottomBar),
                ProxyExplorer(bottomBar: _buildBottomBar),
                //DigimonPage(bottomBar: _buildBottomBar),
                ProxyExplorer(bottomBar: _buildBottomBar)
              ][index]));
    });
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon:
          Icon(Icons.account_tree, color: Theme.of(context).disabledColor),
          activeIcon:
          Icon(Icons.account_tree, color: Theme.of(context).primaryColor),
          label: 'Flowchart',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.text_format_outlined,
              color: Theme.of(context).disabledColor),
          activeIcon: Icon(Icons.text_format_outlined,
              color: Theme.of(context).primaryColor),
          label: 'Labels',
        ),
        /*
        BottomNavigationBarItem(
          icon: Icon(Icons.layers, color: Theme.of(context).disabledColor),
          activeIcon: Icon(Icons.layers, color: Theme.of(context).primaryColor),
          label: 'Overlays',
        ),
        */
        BottomNavigationBarItem(
          icon: Icon(Icons.stacked_line_chart,
              color: Theme.of(context).disabledColor),
          activeIcon: Icon(Icons.stacked_line_chart,
              color: Theme.of(context).primaryColor),
          label: 'Edges',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.teal[800],
      onTap: (index) => _onChangePage(context, index),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Graphite',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        backgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      home: ProxyExplorer(bottomBar: _buildBottomBar),
      routes: <String, WidgetBuilder>{
        '/flowchart': (BuildContext context) =>
            ProxyExplorer(bottomBar: _buildBottomBar),
        '/labels': (BuildContext context) =>
            ProxyExplorer(bottomBar: _buildBottomBar),
        '/complex': (BuildContext context) =>
            ProxyExplorer(bottomBar: _buildBottomBar),
      },
    );
  }
}