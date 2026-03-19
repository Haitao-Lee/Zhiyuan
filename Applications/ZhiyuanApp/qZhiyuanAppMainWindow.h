/*==============================================================================

  Copyright (c) Kitware, Inc.

  See http://www.slicer.org/copyright/copyright.txt for details.

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  This file was originally developed by Julien Finet, Kitware, Inc.
  and was partially funded by NIH grant 3P41RR013218-12S1

==============================================================================*/

#ifndef __qZhiyuanAppMainWindow_h
#define __qZhiyuanAppMainWindow_h

// Zhiyuan includes
#include "qZhiyuanAppExport.h"
class qZhiyuanAppMainWindowPrivate;

// Slicer includes
#include "qSlicerMainWindow.h"

class Q_ZHIYUAN_APP_EXPORT qZhiyuanAppMainWindow : public qSlicerMainWindow
{
  Q_OBJECT
public:
  typedef qSlicerMainWindow Superclass;

  qZhiyuanAppMainWindow(QWidget *parent=0);
  virtual ~qZhiyuanAppMainWindow();

public slots:
  void on_HelpAboutZhiyuanAppAction_triggered();

protected:
  qZhiyuanAppMainWindow(qZhiyuanAppMainWindowPrivate* pimpl, QWidget* parent);

private:
  Q_DECLARE_PRIVATE(qZhiyuanAppMainWindow);
  Q_DISABLE_COPY(qZhiyuanAppMainWindow);
};

#endif
