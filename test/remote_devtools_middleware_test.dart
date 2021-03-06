import 'package:redux_remote_devtools/redux_remote_devtools.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'dart:async';
import 'dart:convert';
import 'package:redux/redux.dart';
import 'package:redux_dev_tools/redux_dev_tools.dart';

class MockSocket extends Mock implements SocketClusterWrapper {}

class MockStore extends Mock implements Store {}

class Next {
  void next(action) {}
}

enum TestActions { SomeAction, SomeOtherAction }

class MockNext extends Mock implements Next {}

void main() {
  group('RemoteDevtoolsMiddleware', () {
    group('constructor', () {
      test('socket is not connected', () {
        var socket = MockSocket();
        RemoteDevToolsMiddleware('example.com', socket: socket);
        verifyNever(socket.connect());
      });
    });
    group('connect', () {
      var socket;
      RemoteDevToolsMiddleware devtools;
      setUp(() {
        socket = MockSocket();
        devtools = RemoteDevToolsMiddleware('example.com', socket: socket);
      });
      test('it connects the socket', () {
        devtools.connect();
        verify(socket.connect());
      });
      test('it sends the login message', () async {
        when(socket.connect()).thenAnswer((_) => Future.value());
        when(socket.id).thenReturn('testId');
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          fn('name', {'type': 'START'});
        });
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        await devtools.connect();
        verify(socket.emit('login', 'master', captureAny));
      });
      test('it sends the start message message', () async {
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        when(socket.id).thenReturn('testId');
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          fn('name', {'type': 'START'});
        });
        await devtools.connect();
        verify(socket.emit('log',
            {'type': 'START', 'id': 'testId', 'name': 'flutter'}, captureAny));
      });
      test('instance name is configurable', () async {
        final coolInstanceName = 'testName';
        devtools = RemoteDevToolsMiddleware('example.com', socket: socket, instanceName: coolInstanceName);
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        when(socket.id).thenReturn('testId');
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          fn('name', {'type': 'START'});
        });
        await devtools.connect();
        verify(socket.emit('log',
            {'type': 'START', 'id': 'testId', 'name': '$coolInstanceName'}, captureAny));
      });
      test('it is in STARTED state', () async {
        when(socket.connect()).thenAnswer((_) => Future.value());
        when(socket.id).thenReturn('testId');
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          fn('name', {'type': 'START'});
        });
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        await devtools.connect();
        expect(devtools.status, RemoteDevToolsStatus.started);
      });
      test('it sends the state', () async {
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          fn('name', {'type': 'START'});
        });
        when(socket.id).thenReturn('testId');
        var store = MockStore();
        when(store.state).thenReturn('TEST STATE');
        devtools.store = store;
        await devtools.connect();
        verify(socket.emit('log',
            {'type': 'START', 'id': 'testId', 'name': 'flutter'}, captureAny));
        verify(socket.emit(
            'log',
            {
              'type': 'ACTION',
              'id': 'testId',
              'name': 'flutter',
              'payload': '"TEST STATE"',
              'action': '{"type":"CONNECT","payload":"CONNECT"}',
              'nextActionId': null
            },
            captureAny));
      });
    });
    group('call', () {
      SocketClusterWrapper socket;
      RemoteDevToolsMiddleware devtools;
      Next next = MockNext();
      Store store;
      setUp(() async {
        store = MockStore();
        when(store.state).thenReturn({'state': 42});
        socket = MockSocket();
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          return fn('name', {'type': 'START'});
        });
        when(socket.id).thenReturn('testId');
        when(socket.connect()).thenAnswer((_) => Future.value());
        devtools = RemoteDevToolsMiddleware('example.com', socket: socket);
        await devtools.connect();
      });
      test('nothing sent if status is not started', () {
        devtools.status = RemoteDevToolsStatus.starting;
        devtools.call(store, TestActions.SomeAction, next.next);
        verifyNever(socket.emit(
            'log',
            {
              'type': 'ACTION',
              'id': 'testId',
              'name': 'flutter',
              'payload': '{"state":42}',
              'action': '{"type":"TestActions.SomeAction"}',
              'nextActionId': null
            },
            captureAny));
      });
      test('the action and state are sent', () {
        devtools.status = RemoteDevToolsStatus.started;
        devtools.call(store, TestActions.SomeAction, next.next);
        verify(socket.emit(
            'log',
            {
              'type': 'ACTION',
              'id': 'testId',
              'name': 'flutter',
              'payload': '{"state":42}',
              'action': '{"type":"TestActions.SomeAction"}',
              'nextActionId': null
            },
            captureAny));
      });
      test('calls next', () {
        devtools.call(store, TestActions.SomeAction, next.next);
        verify(next.next(TestActions.SomeAction));
      });
    });
    group('remote action', () {
      SocketClusterWrapper socket;
      RemoteDevToolsMiddleware devtools;
      Store store;
      setUp(() async {
        store = MockStore();
        when(store.state).thenReturn({'state': 42});
        socket = MockSocket();
        when(socket.emit('login', 'master', captureAny))
            .thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[2];
          fn('testChannel', 'err', 'data');
        });
        when(socket.on('data', captureAny)).thenAnswer((Invocation i) {
          Function fn = i.positionalArguments[1];
          return fn('name', {'type': 'START'});
        });
        when(socket.id).thenReturn('testId');
        when(socket.connect()).thenAnswer((_) => Future.value());
        devtools = RemoteDevToolsMiddleware('example.com', socket: socket);
        devtools.store = store;
        await devtools.connect();
      });
      test('handles time travel', () {
        var remoteData = {
          'type': 'DISPATCH',
          'action': {'type': 'JUMP_TO_STATE', 'index': 4}
        };
        devtools.handleEventFromRemote(remoteData);
        verify(store.dispatch(DevToolsAction.jumpToState(4)));
      });
      test('Dispatches arbitrary remote actions', () {
        var remoteData = {
          'type': 'ACTION',
          'action': '{"type": "TEST ACTION", "value": 12}'
        };
        devtools.handleEventFromRemote(remoteData);
        print(jsonDecode(remoteData['action']));
        var expected = DevToolsAction.perform(jsonDecode(remoteData['action']));
        print(expected);
        var verifyResult = verify(store.dispatch(captureAny)).captured.first;
        expect(verifyResult.type, DevToolsActionTypes.PerformAction);
        expect(verifyResult.appAction['type'], 'TEST ACTION');
        expect(verifyResult.appAction['value'], 12);
      });
      test('Does not dispatch if store has not been sent', () {
        devtools.store = null;
        var remoteData = {
          'type': 'DISPATCH',
          'action': {'type': 'JUMP_TO_STATE', 'index': 4}
        };
        expect(
            () => devtools.handleEventFromRemote(remoteData), returnsNormally);
      });
    });
  });
}
