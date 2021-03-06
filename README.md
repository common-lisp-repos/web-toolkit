<h2 align="center">Lisp Web Toolkit</h2>

<p align="center">
    <a href="https://lisp-web-toolkit.com">lisp-web-toolkit.com</a>
</p>

<p align="center">
Object-oriented Lisp Systems for Rapid Web Application Development
</p>

### Status

[![Build Status](https://travis-ci.org/xh4/web-toolkit.svg?branch=master)](https://travis-ci.org/xh4/web-toolkit)

### Systems

#### HTTP
WT.HTTP provides HTTP functionality as is defined in [RFC 7231 Hypertext Transfer Protocol (HTTP/1.1)](https://www.ietf.org/rfc/rfc7231.txt), together with implementation of server and client.

#### WebSocket
WT.WEBSOCKET provides WebSocket functionality with interfaces inspired by [JSR 356, Java API for WebSocket](https://www.oracle.com/technetwork/articles/java/jsr356-1937161.html). The system is tested against the [Autobahn WebSocket Testsuite](https://github.com/crossbario/autobahn-testsuite).

#### HTML
WT.HTML implements HTML constructor and serializer based on recent version of [HTML Living Standard](https://html.spec.whatwg.org/multipage/).

#### JSON
WT.JSON implements JSON encoder and decoder based on [ECMA-404 The JSON Data Interchange Standard](https://www.json.org/json-en.html).

#### URI
WT.URI provides URI parser and constructor, with support of UTF-8 characters, IPv6 addresses and query parameters handling. It utilize recursive descent [parser combinators](https://www.cs.nott.ac.uk/~pszgmh/monparsing.pdf) to provide a concise implementation that is close to the definition in [RFC 3986 Uniform Resource Identifier (URI): Generic Syntax](https://tools.ietf.org/html/rfc3986).

#### DOM
WT.DOM implements Document Object Model (DOM) based on recent version of [DOM Living Standard](https://dom.spec.whatwg.org/), it covers [Nodes](https://dom.spec.whatwg.org/#nodes) and [Traversal](https://dom.spec.whatwg.org/#traversal).

#### Style
WT.STYLE implements CSS constructor and serializer.

#### Component
WT.COMPONENT provices component abstraction, it combines [Web Components](https://developer.mozilla.org/en-US/docs/Web/Web_Components) style strong encapsulation and [React](https://reactjs.org/) style declarative DOM synchronization.

### Roadmap

* Overall
  * Use in production environments
  * Write [documentation](https://lisp-web-toolkit.com)
  * Carefully design conditions and errors
  * Write more tests
  * <s>Add project build status graph</s>
  * Add code coverage informataion
* HTTP
  * Use [Asynchronous I/O](http://www.lispworks.com/documentation/lw71/LW/html/lw-192.htm) in LispWorks
  * Use [Recursive Event Dispatching (SERVE-EVENT)](https://github.com/sbcl/sbcl/blob/master/src/code/serve-event.lisp) in SBCL 
  * Abandon usocket & bordeaux-threads, write implementation-dependent code
  * Implement server statistics and metrics monitoring
  * Implement traffic throttling and message size limiting
  * Implement authentication, authorization and access control
  * Implement static file serving
  * Implement cache control
  * Implement compression
  * Implement logging
  * Implement [HTTP/2](https://tools.ietf.org/html/rfc7540)
  * Implement common handlers
  * Implement virtual host
  * <s>(Client) Support HTTPS</s>
  * (Client) Support compression and decompression
  * (Client) Support HTTP Proxy
  * (Client) Support SOCKS Proxy
  * (Client) Support Basic Auth
  * (Client) Implement Cookie store
  * (Client) Support caching
* WebSocket
  * Use [Asynchronous I/O](http://www.lispworks.com/documentation/lw71/LW/html/lw-192.htm) in LispWorks
  * Use [Recursive Event Dispatching (SERVE-EVENT)](https://github.com/sbcl/sbcl/blob/master/src/code/serve-event.lisp) in SBCL
  * Implement server statistics and metrics monitoring
  * Implement traffic throttling and message size limiting
  * Support [Compression Extensions](https://tools.ietf.org/html/rfc7692)
  * Support WSS for both client and server
* URI
  * Test against [Web Platform Tests](https://github.com/web-platform-tests/wpt)
* HTML
  * Implement parser
  * Implement pretty print(?)
  * Refine element constractor error report
  * <s>Implement DOM, abandon CXML's DOM implementation</s>
  * Test against [Web Platform Tests](https://github.com/web-platform-tests/wpt)
* JSON
  * Test against [JSONTestSuite](https://github.com/nst/JSONTestSuite)
  * Implement accessors for object
  * Implement identical transformation for JSON values (null, false, [])
* DOM
  * Implement namespace
  * Implement XPath
* Script (Implement JavaScript code transformer)

### Author
[Xiangyu He](https://xh.coobii.com) <[xh@coobii.com](mailto:xh@coobii.com)>

### License
Copyright 2018-2020 Xiangyu He. Released under the 3-Clause BSD License.
