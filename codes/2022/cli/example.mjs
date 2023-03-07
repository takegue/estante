import { execa } from 'execa';
import Listr from 'listr';

const tasks = new Listr([
  {
    title: 'Git',
    task: () => {
      return new Listr([
        {
          title: 'Checking git status',
          task: () => {
            execa('git', ['status', '--porcelain']).then(({stdout, exitCode}) => {
              // if (stdout !== '') {
              //   throw new Error('Unclean working tree. Commit or stash changes first.');
              // }
            });
          },
        },
        {
          title: 'Checking remote history',
          task: () => execa('git', ['rev-list', '--count', '--left-only', '@{u}...HEAD']).then(({exitCode}) => {
            if (exitCode !== 0) {
              throw new Error('Remote history differ. Please pull changes.');
            }
          })
        }
      ], {concurrent: true});
    }
  },
  {
    title: 'Install package dependencies with Yarn',
    task: (ctx, task) => execa('yarn')
    .catch(() => {
      ctx.yarn = false;

      task.skip('Yarn not available, install it via `npm install -g yarn`');
    })
  },
  {
    title: 'Install package dependencies with npm',
    enabled: ctx => ctx.yarn === false,
    task: () => execa('npm', ['install'])
  },
  {
    title: 'Run tests',
    task: () => execa('npm', ['test'])
  },
  {
    title: 'Publish package',
    task: () => execa('npm', ['publish'])
  }
]);

await tasks.run().catch(err => {
  console.error(err);
});
